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

final class ToolbarStore: ObservableObject {
    
    @Published var items: [ToolbarItemType] = []

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
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([ToolbarItemType].self, from: data)
        else {
            items = Array(builtinToolbar.prefix(5))
            return
        }

        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func add(_ item: ToolbarItemType) {
        items.append(item)
        save()
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        save()
    }
    
    func count() -> Int {
        return items.count
    }
}

struct ToolbarDropDelegate: DropDelegate {
    let targetIndex: Int
    let store: ToolbarStore
    @Binding var draggedItemIndex: Int?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItemIndex = nil
        store.save()
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let from = draggedItemIndex,
              store.items.indices.contains(from),
              store.items.indices.contains(targetIndex),
              from != targetIndex else { return }
        
        withAnimation(.default) {
            store.items.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: targetIndex > from ? targetIndex + 1 : targetIndex
            )
            draggedItemIndex = targetIndex
        }
    }
}
