import Foundation

enum Config {
    static let appGroupIdentifier = "group.com.bryce.balance"
    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
}
