import Foundation

enum Config {
    static let appGroupIdentifier = "com.systemsoftware.balance"
    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
