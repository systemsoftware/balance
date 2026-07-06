import Foundation
internal import Combine

final class ChatStore: ObservableObject {
    @Published var items: [ChatSession] = []

    private let defaults = UserDefaults(suiteName: Config.appGroupIdentifier)
    private let profile: String
    private var storageKey: String {
        return profile.isEmpty ? "chats" : "chats_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
    }

    func load() {
        guard
            let data = defaults?.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([ChatSession].self, from: data)
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

    func add(_ bookmark: ChatSession) {
        items.append(bookmark)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
}
