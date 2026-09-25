import Foundation

extension Notification.Name {
    static let cloudPreferencesDidApply = Notification.Name("cloudPreferencesDidApply")
}

final class CloudPreferences {
    static let shared = CloudPreferences()

    private let local = Config.defaults
    private let cloud = NSUbiquitousKeyValueStore.default
    private var localObserver: NSObjectProtocol?
    private var cloudObserver: NSObjectProtocol?
    private var lastValues: [String: Data] = [:]
    private var applyingRemote = false
    private var enabledGroups: Set<String> = []

    private let localOnlyKeys: Set<String> = ["sawSetup"]
    private lazy var settingGroups: [String: String] = {
        Settings.reduce(into: [:]) { groups, setting in
            guard !setting.appStorageKey.isEmpty, setting.category.id != catSync.id else { return }
            groups[setting.appStorageKey] = setting.syncGroup
        }
    }()

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
        enabledGroups = Set(SyncOptions.preferenceKeys.filter { key in SyncOptions.isEnabled(key) })
        reconcile(keys: syncKeys().filter(isEnabled))
        snapshot()
        localObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: local,
            queue: .main
        ) { [weak self] _ in self?.publishChanges() }
    }

    private func isSyncable(_ key: String) -> Bool {
        !SyncOptions.preferenceKeys.contains(key)
            && !SyncOptions.modelKeys.contains(key)
            && key != SyncOptions.inventory
            && key != SyncOptions.pendingDeletionKey
            && !localOnlyKeys.contains(key)
            && !["Downloads", "note_", "pendingCloud", "inventoryCloud", "NS", "Apple"].contains { key.hasPrefix($0) }
    }

    private func group(for key: String) -> String {
        if key == "bookmarks" || key.hasPrefix("bookmarks_") || key == "savedPlaces" { return SyncOptions.bookmarks }
        if key == "pins" || key.hasPrefix("pins_") { return SyncOptions.pins }
        if key == "chats" || key.hasPrefix("chats_") { return SyncOptions.chats }
        if key == "sidebar" || key.hasPrefix("sidebar_") || key == "leftSidebarMode" {
            return SyncOptions.sidebar
        }
        if key == "toolbar" || key.hasPrefix("toolbar_") || key == "showToolbarDragHandle" {
            return SyncOptions.toolbar
        }
        if key == "profiles" || key == "defaultProfile" { return SyncOptions.profiles }
        return settingGroups[key] ?? SyncOptions.settings
    }

    func deleteCloudData(group: String) {
        guard SyncOptions.preferenceKeys.contains(group), !SyncOptions.isEnabled(group) else { return }
        for key in cloud.dictionaryRepresentation.keys where isSyncable(key) && self.group(for: key) == group {
            cloud.removeObject(forKey: key)
        }
        cloud.synchronize()
        snapshot()
    }

    func deleteLegacyDownloadsCloudData() {
        for key in cloud.dictionaryRepresentation.keys where key == "Downloads" || key.hasPrefix("Downloads_") {
            cloud.removeObject(forKey: key)
        }
        cloud.synchronize()
    }

    private func isEnabled(_ key: String) -> Bool {
        SyncOptions.isEnabled(group(for: key))
    }

    private func reconcile(keys: Set<String>) {
        applyingRemote = true
        for key in keys {
            if let value = cloud.object(forKey: key) { local.set(value, forKey: key) }
            else if let value = local.object(forKey: key) { cloud.set(value, forKey: key) }
        }
        applyingRemote = false
        NotificationCenter.default.post(name: .cloudPreferencesDidApply, object: nil, userInfo: ["keys": Array(keys)])
    }

    private func syncKeys() -> Set<String> {
        let localKeys = Set((local.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]).keys)
        return Set(localKeys.filter(isSyncable))
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
        let nowEnabled = Set(SyncOptions.preferenceKeys.filter { key in SyncOptions.isEnabled(key) })
        let newlyEnabled = nowEnabled.subtracting(enabledGroups)
        enabledGroups = nowEnabled
        if !newlyEnabled.isEmpty {
            reconcile(keys: syncKeys().filter { newlyEnabled.contains(group(for: $0)) })
            snapshot()
        }
        let keys = syncKeys().union(lastValues.keys)
        for key in keys {
            guard isEnabled(key) else { continue }
            let value = local.object(forKey: key)
            let data = encoded(value)
            guard data != lastValues[key] else { continue }
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
        for key in keys where isSyncable(key) && isEnabled(key) {
            if let value = cloud.object(forKey: key) { local.set(value, forKey: key) }
            else { local.removeObject(forKey: key) }
        }
        snapshot()
        applyingRemote = false
        NotificationCenter.default.post(name: .cloudPreferencesDidApply, object: nil, userInfo: ["keys": keys])
    }
}
