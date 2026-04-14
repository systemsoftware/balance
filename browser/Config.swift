import Foundation

enum Config {
    static let appGroupIdentifier = "group.com.bryce.browser"
    static let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
}
