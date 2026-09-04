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


let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

let DEFAULT_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
    "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
    "Version/\(major).0 Safari/605.1.15"
