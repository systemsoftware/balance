import Foundation
import SwiftUI
internal import Combine

final class DownloadStore: ObservableObject {
    static let didChange = Notification.Name("BalanceDownloadsDidChange")
    @Published var items: [Download] = []

    @AppStorage("recordDownloadHistory") var recordDownloadHistory: Bool = true

    private var cloudObserver: NSObjectProtocol?
    private var localObserver: NSObjectProtocol?
    private let defaults = Config.defaults
    private let profile: String
    var profileName: String { profile }
    private var storageKey: String {
        return profile.isEmpty ? "Downloads" : "Downloads_\(profile)"
    }

    init(profile: String = "") {
        self.profile = profile
        load()
        cloudObserver = NotificationCenter.default.addObserver(forName: .cloudPreferencesDidApply, object: nil, queue: .main) { [weak self] note in
            guard let self, let keys = note.userInfo?["keys"] as? [String], keys.contains(self.storageKey) else { return }
            self.load()
        }
        localObserver = NotificationCenter.default.addObserver(forName: Self.didChange, object: nil, queue: .main) { [weak self] notification in
            guard let self, notification.object as? String == self.storageKey else { return }
            self.load()
        }
    }

    deinit {
        if let cloudObserver { NotificationCenter.default.removeObserver(cloudObserver) }
        if let localObserver { NotificationCenter.default.removeObserver(localObserver) }
    }

    func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Download].self, from: data)
        else {
            items = []
            return
        }
        items = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
        NotificationCenter.default.post(name: Self.didChange, object: storageKey)
    }

    func add(_ download: Download) {
        if recordDownloadHistory == false {
            return
        }
        items.append(download)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func discard(id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            removeTemporaryFiles(for: item)
        }
        remove(id: id)
    }

    func clearAll() {
        for item in items {
            removeTemporaryFiles(for: item)
        }
        items.removeAll()
        save()
    }

    static func clearAllHistory() {
        let keys = Config.defaults.dictionaryRepresentation().keys.filter {
            $0 == "Downloads" || $0.hasPrefix("Downloads_")
        }
        for key in keys {
            let profile = key == "Downloads" ? "" : String(key.dropFirst("Downloads_".count))
            DownloadStore(profile: profile).clearAll()
        }
    }

    private func removeTemporaryFiles(for item: Download) {
        let temporaryDirectory = FileManager.default.temporaryDirectory.standardizedFileURL
        for path in item.temporaryPaths ?? [] {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.deletingLastPathComponent() == temporaryDirectory else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
