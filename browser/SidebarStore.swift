import Foundation
import SwiftUI
internal import UniformTypeIdentifiers
internal import Combine

final class SidebarStore: ObservableObject {
    
    @Published var items: [SidebarItem] = []

    private let defaults = UserDefaults(suiteName:Config.appGroupIdentifier)
    private let profile: String
    private var storageKey: String {
        return profile.isEmpty ? "sidebar" : "sidebar_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
    }

    func load() {
        guard
            let data = defaults?.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SidebarItem].self, from: data)
        else {
            items = Array(builtInSidebar.prefix(5))
            return
        }

        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: storageKey)
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

struct SidebarDropDelegate: DropDelegate {
    let item: SidebarItem
    let store: SidebarStore
    @Binding var draggedItem: SidebarItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        store.save()
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem,
              draggedItem.id != item.id,
              let from = store.items.firstIndex(where: { $0.id == draggedItem.id }),
              let to = store.items.firstIndex(where: { $0.id == item.id })
        else { return }
        
        if from != to {
            withAnimation(.default) {
                store.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
}
