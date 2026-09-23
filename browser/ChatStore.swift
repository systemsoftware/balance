import Foundation
internal import Combine

final class ChatStore: ObservableObject {
    @Published var items: [ChatSession] = []

    private var cloudObserver: NSObjectProtocol?
    private let defaults = Config.defaults
    private let profile: String
    private var storageKey: String {
        return profile.isEmpty ? "chats" : "chats_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
        cloudObserver = NotificationCenter.default.addObserver(forName: .cloudPreferencesDidApply, object: nil, queue: .main) { [weak self] note in
            guard let self, let keys = note.userInfo?["keys"] as? [String], keys.contains(self.storageKey) else { return }
            self.load()
        }
    }

    func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([ChatSession].self, from: data)
        else {
            items = []
            return
        }
        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func add(_ bookmark: ChatSession) {
        items.append(bookmark)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
}
