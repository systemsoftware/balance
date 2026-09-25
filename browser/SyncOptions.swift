import Foundation

/// Sync switches are local to this device so that turning one off cannot be
/// reversed by a preference arriving from iCloud.
enum SyncOptions {
    static let bookmarks = "syncBookmarks"
    static let pins = "syncPins"
    static let chats = "syncChats"
    static let sidebar = "syncSidebar"
    static let toolbar = "syncToolbar"
    static let profiles = "syncProfiles"
    static let settings = "syncSettings"
    static let inventory = "syncInventory"
    static let autofill = "syncAutofill"
    static let engines = "syncEngines"
    static let forgetOnClose = "syncForgetOnClose"

    static let preferenceKeys = [bookmarks, pins, chats, sidebar, toolbar, profiles, settings]
    static let modelKeys = ["syncHistory", autofill, engines, forgetOnClose]
    static let pendingDeletionKey = "pendingCloudSyncDeletions"
    private(set) static var attachedAtLaunch: Set<String> = []

    static func captureLaunchState() {
        attachedAtLaunch = Set(modelKeys.filter { key in shouldAttachCloudStore(key) })
    }

    static func isEnabled(_ key: String) -> Bool {
        if key == "syncHistory" { return Config.defaults.bool(forKey: key) }
        guard let value = Config.defaults.object(forKey: key) as? Bool else { return true }
        return value
    }

    static func shouldAttachCloudStore(_ key: String) -> Bool {
        isEnabled(key) && !(Config.defaults.stringArray(forKey: pendingDeletionKey) ?? []).contains(key)
    }
}
