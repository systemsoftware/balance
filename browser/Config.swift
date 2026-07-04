import Foundation

enum Config {
    static let appGroupIdentifier = "com.bryce.browser"
    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
}
