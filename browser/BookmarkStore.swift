import Foundation
internal import Combine
import SwiftUI
import AppIntents

final class BookmarkStore: ObservableObject {
    @Published private(set) var items: [Bookmark] = []

    private var cloudObserver: NSObjectProtocol?
    private let defaults = Config.defaults
    private let profile: String
    private var storageKey: String {
        profile.isEmpty ? "bookmarks" : "bookmarks_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
        cloudObserver = NotificationCenter.default.addObserver(forName: .cloudPreferencesDidApply, object: nil, queue: .main) { [weak self] note in
            guard let self, let keys = note.userInfo?["keys"] as? [String], keys.contains(self.storageKey) else { return }
            self.load()
        }
    }

    private func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else {
            items = []
            return
        }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func add(_ bookmark: Bookmark) {
        items.append(bookmark)
        BrowserAppShortcuts.updateAppShortcutParameters()
        save()
    }

    func add(contentsOf bookmarks: [Bookmark]) {
        guard !bookmarks.isEmpty else { return }
        items.append(contentsOf: bookmarks)
        save()
    }

    func update(id: UUID, title: String, url: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = title
        items[index].url = url
        save()
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
