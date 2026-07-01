import Foundation

enum Config {
    static let appGroupIdentifier = "group.com.bryce.browser"
    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
}
