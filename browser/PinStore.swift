import Foundation
internal import Combine
import SwiftUI

final class PinStore: ObservableObject {
    @Published var items: [Bookmark] = []

    private let defaults = UserDefaults(suiteName: Config.appGroupIdentifier)
    private let profile: String
    private var storageKey: String {
        return profile.isEmpty ? "pins" : "pins_\(profile)"
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

    func remove(url: String) {
        items.removeAll { $0.url == url }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
