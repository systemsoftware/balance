import CloudKit
import Foundation
import SwiftData

/// Mirrors Inventory's local catalog into the private CloudKit `Inventory` type.
/// Files use the schema's `file` asset; links use its `url` string.
@MainActor
enum InventoryCloudSync {
    private static let container = CKContainer(identifier: "iCloud.com.systemsoftware.balance")
    private static let database = container.privateCloudDatabase
    private static let zoneID = CKRecordZone.ID(zoneName: "BalanceInventory")
    private static let tokenKey = "inventoryCloudChangeToken"
    private static let uploadedKey = "inventoryCloudUploadedIDs"
    private static let pendingDeletesKey = "inventoryCloudPendingDeletes"
    private static var syncTask: Task<Bool, Never>?
    private static var needsAnotherPass = false
    private static var zoneReady = false
    private(set) static var lastError: String?

    static func enqueueDeletion(id: UUID) {
        var pending = Set(Config.defaults.stringArray(forKey: pendingDeletesKey) ?? [])
        pending.insert(id.uuidString)
        Config.defaults.set(Array(pending), forKey: pendingDeletesKey)
    }

    static func waitForCurrentSync() async {
        _ = await syncTask?.value
    }

    static func didDeleteCloudData() {
        zoneReady = false
        Config.defaults.removeObject(forKey: tokenKey)
        Config.defaults.removeObject(forKey: uploadedKey)
        Config.defaults.removeObject(forKey: pendingDeletesKey)
        lastError = nil
    }

    static func sync() async -> Bool {
        guard SyncOptions.isEnabled(SyncOptions.inventory) else {
            lastError = nil
            return true
        }
        if let syncTask {
            needsAnotherPass = true
            return await syncTask.value
        }
        let task = Task {
            var result: Bool
            repeat {
                needsAnotherPass = false
                result = await performSync()
            } while result && needsAnotherPass
            return result
        }
        syncTask = task
        let result = await task.value
        syncTask = nil
        return result
    }

    private static func performSync() async -> Bool {
        guard let context = InventorySidebar.sharedContainer?.mainContext else { return false }
        do {
            if !zoneReady {
                _ = try await database.save(CKRecordZone(zoneID: zoneID))
                zoneReady = true
            }
            try await deletePendingRecords()
            try await receiveChanges(into: context)
            try await uploadLocalItems(from: context)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            print("❌ Inventory iCloud sync failed; local items are preserved: \(error)")
            return false
        }
    }

    private static func deletePendingRecords() async throws {
        var pending = Set(Config.defaults.stringArray(forKey: pendingDeletesKey) ?? [])
        var uploaded = Set(Config.defaults.stringArray(forKey: uploadedKey) ?? [])
        for id in pending {
            let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
            do {
                _ = try await database.deleteRecord(withID: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                // Already removed by another device.
            }
            pending.remove(id)
            uploaded.remove(id)
            Config.defaults.set(Array(pending), forKey: pendingDeletesKey)
            Config.defaults.set(Array(uploaded), forKey: uploadedKey)
        }
    }

    private static func receiveChanges(into context: ModelContext) async throws {
        var token = savedToken()
        var isFullFetch = token == nil
        var seenIDs = Set<String>()
        repeat {
            let page: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>], deletions: [CKDatabase.RecordZoneChange.Deletion], changeToken: CKServerChangeToken, moreComing: Bool)
            do {
                page = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: token,
                    desiredKeys: ["id", "name", "mime", "url", "file"],
                    resultsLimit: 100
                )
            } catch {
                guard token != nil, isExpiredChangeToken(error) else { throw error }
                // CloudKit commonly wraps the zone's token error in a
                // partialFailure keyed by CKRecordZone.ID.
                Config.defaults.removeObject(forKey: tokenKey)
                token = nil
                isFullFetch = true
                seenIDs.removeAll()
                continue
            }

            var uploaded = Set(Config.defaults.stringArray(forKey: uploadedKey) ?? [])
            let pending = Set(Config.defaults.stringArray(forKey: pendingDeletesKey) ?? [])
            var filesToRemove: [InventoryItem] = []
            for result in page.modificationResultsByID.values {
                let record = try result.get().record
                guard record.recordType == "Inventory" else { continue }
                let idString = (record["id"] as? String) ?? record.recordID.recordName
                guard let id = UUID(uuidString: idString), !pending.contains(id.uuidString) else { continue }
                try importRecord(record, id: id, into: context)
                uploaded.insert(id.uuidString)
                seenIDs.insert(id.uuidString)
            }
            for deletion in page.deletions where deletion.recordType == "Inventory" {
                guard let id = UUID(uuidString: deletion.recordID.recordName) else { continue }
                guard uploaded.contains(id.uuidString) else { continue }
                if let item = try context.fetch(FetchDescriptor<InventoryItem>()).first(where: { $0.id == id }) {
                    filesToRemove.append(item)
                    context.delete(item)
                }
                uploaded.remove(id.uuidString)
            }
            try context.save()
            filesToRemove.forEach(removeLocalFile)
            Config.defaults.set(Array(uploaded), forKey: uploadedKey)
            token = page.changeToken
            if !page.moreComing {
                if isFullFetch {
                    // A full fetch has no deletion events for records removed before
                    // the saved token expired. Reconcile only previously uploaded IDs.
                    filesToRemove.removeAll()
                    for idString in uploaded.subtracting(seenIDs) {
                        guard let id = UUID(uuidString: idString) else { continue }
                        if let item = try context.fetch(FetchDescriptor<InventoryItem>()).first(where: { $0.id == id }) {
                            filesToRemove.append(item)
                            context.delete(item)
                        }
                        uploaded.remove(idString)
                    }
                    try context.save()
                    filesToRemove.forEach(removeLocalFile)
                    Config.defaults.set(Array(uploaded), forKey: uploadedKey)
                }
                saveToken(page.changeToken)
                break
            }
            if !isFullFetch { saveToken(page.changeToken) }
        } while true
    }

    private static func isExpiredChangeToken(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .changeTokenExpired { return true }
        guard cloudError.code == .partialFailure,
              let nested = cloudError.partialErrorsByItemID,
              !nested.isEmpty else { return false }
        return nested.values.allSatisfy { ($0 as? CKError)?.code == .changeTokenExpired }
    }

    private static func importRecord(_ record: CKRecord, id: UUID, into context: ModelContext) throws {
        let name = (record["name"] as? String) ?? id.uuidString
        let mime = (record["mime"] as? String) ?? "application/octet-stream"
        let url: URL
        let isLink: Bool
        if let asset = record["file"] as? CKAsset, let source = asset.fileURL {
            let directory = inventoryDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let component = URL(fileURLWithPath: name).lastPathComponent
            let safeName = component.isEmpty || component == "." || component == ".."
                ? id.uuidString : component
            let destination = directory.appendingPathComponent(safeName)
            let temporary = directory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: source, to: temporary)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
            url = destination
            isLink = false
        } else if let address = record["url"] as? String,
                  let link = URL(string: address), !address.isEmpty {
            url = link
            isLink = true
        } else {
            throw InventorySyncError.missingContent(id)
        }

        if let item = try context.fetch(FetchDescriptor<InventoryItem>()).first(where: { $0.id == id }) {
            if item.url != url { removeLocalFile(for: item) }
            item.name = name
            item.mime = mime
            item.url = url
            item.isRemoteLink = isLink
        } else {
            context.insert(InventoryItem(id: id, name: name, url: url, mime: mime, isRemoteLink: isLink))
        }
    }

    private static func uploadLocalItems(from context: ModelContext) async throws {
        var uploaded = Set(Config.defaults.stringArray(forKey: uploadedKey) ?? [])
        let pending = Set(Config.defaults.stringArray(forKey: pendingDeletesKey) ?? [])
        for item in try context.fetch(FetchDescriptor<InventoryItem>()) {
            let id = item.id.uuidString
            guard !uploaded.contains(id), !pending.contains(id) else { continue }
            let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
            let record = CKRecord(recordType: "Inventory", recordID: recordID)
            record["id"] = id as NSString
            record["name"] = item.name as NSString
            record["mime"] = item.mime as NSString
            record["url"] = (item.isRemoteLink ? item.url.absoluteString : "") as NSString
            if !item.isRemoteLink {
                guard FileManager.default.fileExists(atPath: item.url.path) else {
                    throw InventorySyncError.missingLocalFile(item.url)
                }
                record["file"] = CKAsset(fileURL: item.url)
            }
            _ = try await database.save(record)
            uploaded.insert(id)
            Config.defaults.set(Array(uploaded), forKey: uploadedKey)
        }
    }

    private static var inventoryDirectory: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Inventory", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func removeLocalFile(for item: InventoryItem) {
        guard !item.isRemoteLink,
              item.url.standardizedFileURL.path.hasPrefix(inventoryDirectory.standardizedFileURL.path + "/") else { return }
        try? FileManager.default.removeItem(at: item.url)
    }

    private static func savedToken() -> CKServerChangeToken? {
        guard let data = Config.defaults.data(forKey: tokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private static func saveToken(_ token: CKServerChangeToken) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
        Config.defaults.set(data, forKey: tokenKey)
    }
}

private enum InventorySyncError: LocalizedError {
    case missingContent(UUID)
    case missingLocalFile(URL)

    var errorDescription: String? {
        switch self {
        case .missingContent(let id): "Inventory record \(id) has no file or URL"
        case .missingLocalFile(let url): "Inventory file is missing: \(url.lastPathComponent)"
        }
    }
}
