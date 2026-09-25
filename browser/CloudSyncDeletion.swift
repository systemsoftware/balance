import CloudKit
import Foundation

/// Deletes one sync category from the private iCloud database while preserving
/// its local store. SwiftData categories are queued until the next launch.
@MainActor
enum CloudSyncDeletion {
    private static let database = CKContainer(identifier: "iCloud.com.systemsoftware.balance").privateCloudDatabase
    private static let modelZone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")
    private static let inventoryZone = CKRecordZone.ID(zoneName: "BalanceInventory")
    private static let recordTypes = [
        "syncHistory": "CD_HistoryItem",
        SyncOptions.autofill: "CD_AutoFillItem",
        SyncOptions.engines: "CD_EngineItem",
        SyncOptions.forgetOnClose: "CD_ForgetOnClose"
    ]
    private static var cleanupTask: Task<Bool, Never>?

    static func enqueue(_ key: String) {
        guard key == SyncOptions.inventory || recordTypes[key] != nil else { return }
        var pending = Set(Config.defaults.stringArray(forKey: SyncOptions.pendingDeletionKey) ?? [])
        pending.insert(key)
        Config.defaults.set(Array(pending), forKey: SyncOptions.pendingDeletionKey)
    }

    static func retryPending(only requestedKey: String? = nil) async -> Bool {
        if let cleanupTask { return await cleanupTask.value }
        let task = Task { await processPending(only: requestedKey) }
        cleanupTask = task
        let result = await task.value
        cleanupTask = nil
        return result
    }

    private static func processPending(only requestedKey: String?) async -> Bool {
        let pending = Config.defaults.stringArray(forKey: SyncOptions.pendingDeletionKey) ?? []
        for key in pending {
            if let requestedKey, key != requestedKey { continue }
            do {
                if key == SyncOptions.inventory {
                    await InventoryCloudSync.waitForCurrentSync()
                    do {
                        _ = try await database.deleteRecordZone(withID: inventoryZone)
                    } catch let error as CKError where error.code == .zoneNotFound {
                        // The account has no Inventory zone yet.
                    }
                    InventoryCloudSync.didDeleteCloudData()
                } else if let recordType = recordTypes[key] {
                    try await deleteRecords(ofType: recordType)
                } else {
                    continue
                }
                var remaining = Config.defaults.stringArray(forKey: SyncOptions.pendingDeletionKey) ?? []
                remaining.removeAll { $0 == key }
                Config.defaults.set(remaining, forKey: SyncOptions.pendingDeletionKey)
            } catch {
                print("❌ Failed to delete iCloud data for \(key); will retry: \(error)")
                return false
            }
        }
        return true
    }

    private static func deleteRecords(ofType recordType: String) async throws {
        var token: CKServerChangeToken?
        var ids: [CKRecord.ID] = []
        do {
            repeat {
                let page = try await database.recordZoneChanges(
                    inZoneWith: modelZone, since: token, desiredKeys: [], resultsLimit: 200
                )
                for result in page.modificationResultsByID.values {
                    let record = try result.get().record
                    if record.recordType == recordType { ids.append(record.recordID) }
                }
                token = page.changeToken
                if !page.moreComing { break }
            } while true
        } catch let error as CKError where error.code == .zoneNotFound {
            return
        }

        for start in stride(from: 0, to: ids.count, by: 200) {
            let batch = Array(ids[start..<min(start + 200, ids.count)])
            let result = try await database.modifyRecords(saving: [], deleting: batch, atomically: false)
            for deletion in result.deleteResults.values {
                if case .failure(let error) = deletion {
                    if let cloudError = error as? CKError, cloudError.code == .unknownItem { continue }
                    throw error
                }
            }
        }
    }
}
