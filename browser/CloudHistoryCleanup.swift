import CloudKit
import Foundation

/// Removes history records from the private CloudKit zone used by SwiftData.
/// A pending request survives offline failures and is retried on app launch.
@MainActor
enum CloudHistoryCleanup {
    private static let pendingKey = "pendingCloudHistoryClears"
    private static let allProfiles = "*"
    private static let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")
    private static let database = CKContainer(identifier: "iCloud.com.systemsoftware.balance").privateCloudDatabase
    private static var cleanupTask: Task<Bool, Never>?

    static func enqueue(profile: String?) {
        var pending = Set(Config.defaults.stringArray(forKey: pendingKey) ?? [])
        if let profile {
            if !pending.contains(allProfiles) { pending.insert(profile) }
        } else {
            pending = [allProfiles]
        }
        Config.defaults.set(Array(pending), forKey: pendingKey)
    }

    static func retryPending() async -> Bool {
        if let cleanupTask { return await cleanupTask.value }
        let task = Task { await processPending() }
        cleanupTask = task
        let result = await task.value
        cleanupTask = nil
        return result
    }

    private static func processPending() async -> Bool {
        while let scope = Config.defaults.stringArray(forKey: pendingKey)?.first {
            do {
                try await deleteRecords(profile: scope == allProfiles ? nil : scope)
                var pending = Config.defaults.stringArray(forKey: pendingKey) ?? []
                pending.removeAll { $0 == scope }
                Config.defaults.set(pending, forKey: pendingKey)
            } catch {
                print("❌ Failed to clear iCloud history; will retry: \(error)")
                return false
            }
        }
        return true
    }

    private static func deleteRecords(profile: String?) async throws {
        var token: CKServerChangeToken?
        var ids: [CKRecord.ID] = []
        do {
            repeat {
                let page = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: token,
                    desiredKeys: ["CD_profile"],
                    resultsLimit: 200
                )
                for result in page.modificationResultsByID.values {
                    let record = try result.get().record
                    guard record.recordType == "CD_HistoryItem" else { continue }
                    if profile == nil || (record["CD_profile"] as? String ?? "") == profile {
                        ids.append(record.recordID)
                    }
                }
                token = page.changeToken
                if !page.moreComing { break }
            } while true
        } catch let error as CKError where error.code == .zoneNotFound {
            return // No history has ever been uploaded from this account.
        }

        for start in stride(from: 0, to: ids.count, by: 200) {
            let batch = Array(ids[start..<min(start + 200, ids.count)])
            let result = try await database.modifyRecords(
                saving: [], deleting: batch, atomically: false
            )
            for deletion in result.deleteResults.values {
                if case .failure(let error) = deletion {
                    if let cloudError = error as? CKError, cloudError.code == .unknownItem { continue }
                    throw error
                }
            }
        }
    }
}
