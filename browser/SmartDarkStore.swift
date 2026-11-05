import Foundation

struct SmartDarkModePreferences {
    private static let key = "SmartDarkModePreferences"

    static var enabledHosts: [String] {
        let overrides = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
        return overrides.compactMap { $0.value ? $0.key.lowercased() : nil }.sorted()
    }

    static func isEnabled(for url: URL?) -> Bool {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host else { return false }
        return isEnabled(for: host.lowercased())
    }

    static func isEnabled(for domain: String) -> Bool {
        let overrides = UserDefaults.standard.dictionary(
            forKey: key
        ) as? [String: Bool] ?? [:]

        return overrides[domain.lowercased()] ?? false
    }

    static func setEnabled(_ enabled: Bool, for domain: String) {
        var overrides = UserDefaults.standard.dictionary(
            forKey: key
        ) as? [String: Bool] ?? [:]

        overrides[domain.lowercased()] = enabled

        UserDefaults.standard.set(overrides, forKey: key)
    }
}
