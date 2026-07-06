import Foundation
internal import Combine
import SwiftUI

final class BookmarkStore: ObservableObject {
    @Published var items: [Bookmark] = []

    private let defaults = UserDefaults(suiteName: Config.appGroupIdentifier)
    private let profile: String
    private var storageKey: String {
        return profile.isEmpty ? "bookmarks" : "bookmarks_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
    }

    func load() {
        guard
            let data = defaults?.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
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

    func add(_ bookmark: Bookmark) {
        items.append(bookmark)
        save()
    }

    func update(id: UUID, title: String, url: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].title = title
            items[index].url = url
            save()
        }
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
