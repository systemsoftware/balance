import Foundation
internal import Combine

final class DownloadStore: ObservableObject {
    @Published var items: [Download] = []

    private let defaults = UserDefaults(suiteName: "group.com.bryce.browser")
    private let profile: String
    private var storageKey: String {
        return profile.isEmpty ? "Downloads" : "Downloads_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
    }

    func load() {
        guard
            let data = defaults?.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Download].self, from: data)
        else {
            items = []
            return
        }
        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: storageKey)
    }

    func add(_ download: Download) {
        items.append(download)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
}
