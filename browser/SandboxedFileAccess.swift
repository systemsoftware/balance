import AppKit
import Foundation

/// Manages sandbox-scoped access to browser profile directories.
///
/// Under App Sandbox, `FileManager` calls against paths like
/// `~/Library/Application Support/Google/Chrome` fail silently (or throw
/// "Operation not permitted") because the process has no entitlement for
/// them. There is no programmatic way around this — the only sanctioned
/// path is to let the user grant access via `NSOpenPanel`, then persist
/// a security-scoped bookmark so we don't have to ask on every launch.
final class SandboxedFileAccess {
    static let shared = SandboxedFileAccess()
    private init() {}

    private func bookmarkKey(for browser: ImportBrowser) -> String {
        "sandboxBookmark.\(browser.rawValue)"
    }

    func resolvedAccessURL(for browser: ImportBrowser, completion: @escaping (URL?) -> Void) {
        if let cached = resolveCachedBookmark(for: browser) {
            completion(cached)
            return
        }
        requestAccess(for: browser, completion: completion)
    }

    private func resolveCachedBookmark(for browser: ImportBrowser) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey(for: browser)) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale, url.startAccessingSecurityScopedResource() else {
            return nil
        }
        return url
    }

    private func requestAccess(for browser: ImportBrowser, completion: @escaping (URL?) -> Void) {
        let suggested = URL(fileURLWithPath: browserFolderPath(for: browser))

        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.message = "Balance needs your permission to read \(browser.rawValue) data (bookmarks, history, saved passwords)."
            panel.prompt = "Grant Access"
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = false
            panel.allowsMultipleSelection = false

            panel.directoryURL = suggested

            let response = panel.runModal()
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }

            guard url.startAccessingSecurityScopedResource() else {
                completion(nil)
                return
            }

            if let bookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(bookmark, forKey: self.bookmarkKey(for: browser))
            }

            completion(url)
        }
    }

    private func browserFolderPath(for browser: ImportBrowser) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch browser {
        case .chrome:
            return "\(home)/Library/Application Support/Google/Chrome"
        case .edge:
            return "\(home)/Library/Application Support/Microsoft Edge"
        case .firefox:
            return "\(home)/Library/Application Support/Firefox"
        }
    }

    func release(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
