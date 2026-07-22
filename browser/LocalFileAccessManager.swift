import AppKit
import Foundation

final class LocalFileAccessManager {
    static let shared = LocalFileAccessManager()
    private let defaultsKey = "localFileBookmarks_v1"
    private var activeBookmarks: [URL] = []
    private var powerboxPaths: Set<String> = []
    private init() { restoreBookmarks() }
    deinit { activeBookmarks.forEach { $0.stopAccessingSecurityScopedResource() } }
    func registerPowerboxURL(_ url: URL) {
        powerboxPaths.insert(url.standardized.path)
        powerboxPaths.insert(url.deletingLastPathComponent().standardized.path)
    }
    func grantedAccessURL(for fileURL: URL) -> URL? {
        let tp = fileURL.standardized.path
        if let b = activeBookmarks.filter({ tp.hasPrefix($0.standardized.path+"/") || tp == $0.standardized.path }).sorted(by:{ $0.path.count > $1.path.count }).first { return b }
        for path in powerboxPaths { if tp == path || tp.hasPrefix(path+"/") { return URL(fileURLWithPath: path, isDirectory: true) } }
        return nil
    }
    func isPowerboxGranted(for fileURL: URL) -> Bool {
        let tp = fileURL.standardized.path
        return powerboxPaths.contains { tp == $0 || tp.hasPrefix($0+"/") }
    }
    @MainActor func requestDirectoryAccess(suggestedDirectory: URL, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = suggestedDirectory
        panel.title = "Allow Local File Access"
        panel.message = "Select the folder containing your web project. Balance only needs access once per project."
        panel.prompt = "Grant Access"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { DispatchQueue.main.async { completion(nil) }; return }
            self?.storeBookmark(url: url)
            DispatchQueue.main.async { completion(url) }
        }
    }
    private func storeBookmark(url: URL) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        if url.startAccessingSecurityScopedResource() { activeBookmarks.append(url) }
        var saved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String:Data] ?? [:]
        saved[url.path] = data
        UserDefaults.standard.set(saved, forKey: defaultsKey)
    }
    private func restoreBookmarks() {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String:Data] else { return }
        for (_,data) in saved {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale), !isStale else { continue }
            if url.startAccessingSecurityScopedResource() { activeBookmarks.append(url) }
        }
    }
}
