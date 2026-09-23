import Foundation

extension Notification.Name {
    static let cloudPreferencesDidApply = Notification.Name("cloudPreferencesDidApply")
}

/// Mirrors small, user-created browser data and preferences to the user's iCloud account.
/// Local defaults remain the immediate, offline source of truth for SwiftUI's AppStorage.
final class CloudPreferences {
    static let shared = CloudPreferences()

    private let local = Config.defaults
    private let cloud = NSUbiquitousKeyValueStore.default
    private var localObserver: NSObjectProtocol?
    private var cloudObserver: NSObjectProtocol?
    private var lastValues: [String: Data] = [:]
    private var applyingRemote = false

    private let exactKeys: Set<String> = [
        "bookmarks", "pins", "chats", "Downloads", "savedPlaces", "sidebar", "toolbar", "rssFeeds",
        "profiles", "defaultProfile", "notepad", "instructions", "homepage",
        "searchURL", "autofillEngine", "userAgent", "themePreference",
        "backgroundType", "backgroundShape", "homeBackground", "homepageWeatherCity",
        "homepageShowCock", "homepageShowWeather", "homepageShowBookmarks",
        "homepageShowEmail", "homepageShowStories", "homepageShowCalendar",
        "bookmarkBar", "bookmarkbarLocation", "tabMode", "showSpaces",
        "tabBackground", "showNewTabButton", "showSidebar", "sidebarWidth",
        "leftSidebarWidth", "leftSidebarMode", "sidebarBackgroundType",
        "toolbarLocation", "toolbarBackgrounds", "showToolbarDragHandle",
        "showAddressBarAutofill", "paletteShowTabs", "paletteShowBookmarks",
        "paletteShowSearch", "paletteShowCommands", "paletteShowHistory",
        "paletteSectionOrder", "usePDFKit", "renderMd", "renderJSON",
        "loadImages", "calDays", "recordHistory", "enableHandoff",
        "formAutofillEnabled", "globalPrivacyControl", "developerMode",
        "defaultPageZoom", "httpsOnly", "openLinksInBackground",
        "temp", "maxTokens", "pageCutoff", "site_permissions_v1",
        "savedSessionState",
        "preserveOnClose", "clearHistoryOnClose", "clearDownloadHistoryOnClose",
        "clearCacheOnClose", "clearCookiesOnClose"
    ]

    private init() {}

    func start() {
        guard localObserver == nil else { return }
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] notification in
            self?.receive(notification)
        }
        cloud.synchronize()
        // Existing iCloud values take precedence on a newly installed device.
        for key in syncKeys() {
            if let value = cloud.object(forKey: key) {
                local.set(value, forKey: key)
            } else if let value = local.object(forKey: key) {
                cloud.set(value, forKey: key)
            }
        }
        snapshot()
        localObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: local,
            queue: .main
        ) { [weak self] _ in self?.publishChanges() }
    }

    private func isSyncable(_ key: String) -> Bool {
        exactKeys.contains(key) || ["bookmarks_", "pins_", "chats_", "Downloads_", "sidebar_", "toolbar_", "boost_"].contains { key.hasPrefix($0) }
    }

    private func syncKeys() -> Set<String> {
        Set(local.dictionaryRepresentation().keys.filter(isSyncable))
            .union(cloud.dictionaryRepresentation.keys.filter(isSyncable))
    }

    private func encoded(_ value: Any?) -> Data? {
        guard let value else { return nil }
        return try? PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }

    private func snapshot() {
        lastValues = Dictionary(uniqueKeysWithValues: syncKeys().compactMap { key in
            encoded(local.object(forKey: key)).map { (key, $0) }
        })
    }

    private func publishChanges() {
        guard !applyingRemote else { return }
        let keys = syncKeys().union(lastValues.keys)
        for key in keys {
            let value = local.object(forKey: key)
            let data = encoded(value)
            guard data != lastValues[key] else { continue }
            // The ubiquitous key-value store has a 1 MB account quota. Large
            // collections remain local instead of silently exhausting it.
            guard data == nil || data!.count < 64_000 else {
                print("iCloud preference value exceeds the sync limit: \(key)")
                continue
            }
            if let value { cloud.set(value, forKey: key) }
            else { cloud.removeObject(forKey: key) }
            lastValues[key] = data
        }
    }

    private func receive(_ notification: Notification) {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        applyingRemote = true
        for key in keys where isSyncable(key) {
            if let value = cloud.object(forKey: key) { local.set(value, forKey: key) }
            else { local.removeObject(forKey: key) }
        }
        snapshot()
        applyingRemote = false
        NotificationCenter.default.post(name: .cloudPreferencesDidApply, object: nil, userInfo: ["keys": keys])
    }
}
