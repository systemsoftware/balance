import Foundation
import MapKit
import SwiftUI
internal import Combine

struct PlaceItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var sourceURL: String?
}

final class PlaceStore: ObservableObject {
    @Published var items: [PlaceItem] = []
    
    private let defaults = UserDefaults(suiteName: "group.com.bryce.browser")
    
    init() {
        load()
    }
    
    func load() {
        guard
            let data = defaults?.data(forKey: "savedPlaces"),
            let decoded = try? JSONDecoder().decode([PlaceItem].self, from: data)
        else {
            return
        }
        items = decoded
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults?.set(data, forKey: "savedPlaces")
    }
    
    func add(_ item: PlaceItem) {
        // Prevent duplicates by name and approx coordinates
        if !items.contains(where: { $0.name == item.name && abs($0.latitude - item.latitude) < 0.0001 && abs($0.longitude - item.longitude) < 0.0001 }) {
            items.append(item)
            save()
        }
    }
    
    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }
}
