import Foundation
import SwiftUI
internal import Combine

final class SidebarStore: ObservableObject {
    
    @Published var items: [SidebarItem] = []

    private let defaults = UserDefaults(suiteName: "group.com.bryce.browser")

    init() {
        load()
    }

    func load() {
        guard
            let data = defaults?.data(forKey: "sidebar"),
            let decoded = try? JSONDecoder().decode([SidebarItem].self, from: data)
        else {
            items = builtInSidebar
            return
        }

        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: "sidebar")
    }

    func add(_ item: SidebarItem) {
        items.append(item)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
    
    func count() -> Int {
        return items.count
    }
}
