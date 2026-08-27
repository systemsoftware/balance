import Foundation
import SwiftUI
internal import UniformTypeIdentifiers
internal import Combine


let builtinToolbar: [ToolbarItemType] = [
    .navigation,
    .share,
    .reload,
    .addressBar,
    .extensions,
    .more
]

struct ToolbarEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let item: ToolbarItemType

    init(id: UUID = UUID(), item: ToolbarItemType) {
        self.id = id
        self.item = item
    }
}

final class ToolbarStore: ObservableObject {
    
    @Published private(set) var items: [ToolbarEntry] = []

    private let defaults = Config.defaults
    private let profile: String
    private var storageKey: String {
        return profile.isEmpty ? "toolbar" : "toolbar_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
    }

    func load() {
        guard
            let data = defaults.data(forKey: storageKey)
        else {
            items = Array(builtinToolbar.prefix(5)).map { ToolbarEntry(item: $0) }
            return
        }

        if let decoded = try? JSONDecoder().decode([ToolbarEntry].self, from: data) {
            items = decoded
        } else if let legacyItems = try? JSONDecoder().decode([ToolbarItemType].self, from: data) {
            items = legacyItems.map { ToolbarEntry(item: $0) }
            save()
        } else {
            items = Array(builtinToolbar.prefix(5)).map { ToolbarEntry(item: $0) }
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func add(_ item: ToolbarItemType) {
        items.append(ToolbarEntry(item: item))
        save()
    }

    func remove(id: UUID) {
        guard items.count > 1, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        save()
    }

    func contains(_ item: ToolbarItemType) -> Bool {
        items.contains { $0.item == item }
    }

    func move(_ draggedID: UUID, before targetID: UUID) {
        guard draggedID != targetID,
              let from = items.firstIndex(where: { $0.id == draggedID }),
              let target = items.firstIndex(where: { $0.id == targetID }) else { return }

        items.move(
            fromOffsets: IndexSet(integer: from),
            toOffset: target > from ? target + 1 : target
        )
    }
    
    func count() -> Int {
        return items.count
    }
}

struct ToolbarDropDelegate: DropDelegate {
    let targetID: UUID
    let store: ToolbarStore
    @Binding var draggedItemID: UUID?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        store.save()
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItemID, draggedItemID != targetID else { return }
        
        withAnimation(.default) {
            store.move(draggedItemID, before: targetID)
        }
    }
}
