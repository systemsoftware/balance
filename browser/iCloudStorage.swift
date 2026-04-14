import Foundation
import SwiftUI

@propertyWrapper
struct iCloudStorage<Value: Codable> {
    private let key: String
    private let store: NSUbiquitousKeyValueStore

    init(_ key: String, store: NSUbiquitousKeyValueStore = .default) {
        self.key = key
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else {
                return [] as! Value
            }
            return value
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
            store.synchronize()
        }
    }
}

extension iCloudStorage {
    func binding(default defaultValue: Value) -> Binding<Value> {
        let key = self.key
        let store = self.store

        return Binding(
            get: {
                guard let data = store.data(forKey: key),
                      let value = try? JSONDecoder().decode(Value.self, from: data)
                else {
                    return defaultValue
                }
                return value
            },
            set: { newValue in
                if let data = try? JSONEncoder().encode(newValue) {
                    store.set(data, forKey: key)
                    store.synchronize()
                }
            }
        )
    }
}
