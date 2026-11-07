import Foundation

struct SiteProfileStore {
    private let key = "siteProfileOverrides"

    var profilesByHost: [String: UUID] {
        let stored = Config.defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        var profiles: [String: UUID] = [:]
        // Prefer an existing apex rule if old settings contain both spellings.
        for host in stored.keys.sorted(by: { ($0.lowercased().hasPrefix("www.") ? 0 : 1, $0) < ($1.lowercased().hasPrefix("www.") ? 0 : 1, $1) }) {
            if let canonicalHost = Self.normalizedHost(host),
               let id = stored[host].flatMap(UUID.init(uuidString:)) {
                profiles[canonicalHost] = id
            }
        }
        return profiles
    }

    func profileID(for url: URL) -> UUID? {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host else { return nil }
        return profileID(forHost: host)
    }

    func profileID(forHost host: String) -> UUID? {
        guard let host = Self.normalizedHost(host) else { return nil }
        return profilesByHost[host]
    }

    func hosts(for profileID: UUID) -> [String] {
        profilesByHost
            .filter { $0.value == profileID }
            .map(\.key)
            .sorted()
    }

    func setProfile(_ profileID: UUID, forHost host: String) {
        guard let host = Self.normalizedHost(host) else { return }
        var stored = Config.defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        stored.keys.filter { Self.normalizedHost($0) == host }.forEach { stored.removeValue(forKey: $0) }
        stored[host] = profileID.uuidString
        Config.defaults.set(stored, forKey: key)
    }

    func removeProfile(forHost host: String) {
        guard let host = Self.normalizedHost(host) else { return }
        var stored = Config.defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        stored.keys.filter { Self.normalizedHost($0) == host }.forEach { stored.removeValue(forKey: $0) }
        Config.defaults.set(stored, forKey: key)
    }

    private static func normalizedHost(_ host: String) -> String? {
        let input = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = input.contains("://") ? input : "https://\(input)"
        guard let components = URLComponents(string: address),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let hostname = components.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !hostname.isEmpty else { return nil }
        return hostname.hasPrefix("www.") ? String(hostname.dropFirst(4)) : hostname
    }
}
