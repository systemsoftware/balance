import Foundation

enum Config {
    static let appGroupIdentifier = "com.systemsoftware.balance"

    private static let didMigrateLegacyDefaults: Void = {
        guard let legacyValues = UserDefaults.standard.persistentDomain(
            forName: appGroupIdentifier
        ) else { return }

        let defaults = UserDefaults.standard
        for (key, value) in legacyValues where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }()

    static var defaults: UserDefaults {
        _ = didMigrateLegacyDefaults
        return .standard
    }

    static var sharedDefaults: UserDefaults? {
        defaults
    }
}
