import Foundation
internal import Combine

final class BookmarkStore: ObservableObject {
    @Published var items: [Bookmark] = []

    private let defaults = UserDefaults(suiteName: "group.com.bryce.browser")

    init() {
        load()
    }

    func load() {
        guard
            let data = defaults?.data(forKey: "bookmarks"),
            let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else {
            items = []
            return
        }
        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: "bookmarks")
    }

    func add(_ bookmark: Bookmark) {
        items.append(bookmark)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
}
