import Foundation

#if canImport(UIKit)
import UIKit
internal import UniformTypeIdentifiers
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages security-scoped access to browser profile directories.
final class SandboxedFileAccess {
    static let shared = SandboxedFileAccess()
    #if canImport(UIKit)
    private var pickerDelegate: DirectoryPickerDelegate?
    #endif
    private init() {}

    private func bookmarkKey(for browser: ImportBrowser) -> String {
        "sandboxBookmark.\(browser.rawValue)"
    }

    func resolvedAccessURL(for browser: ImportBrowser, completion: @escaping (URL?) -> Void) {
        if let url = resolveCachedBookmark(for: browser) { completion(url) }
        else { requestAccess(for: browser, completion: completion) }
    }

    private func resolveCachedBookmark(for browser: ImportBrowser) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey(for: browser)) else { return nil }
        var stale = false
        #if canImport(AppKit)
        let options: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(resolvingBookmarkData: data, options: options,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              !stale, url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }

    private func requestAccess(for browser: ImportBrowser, completion: @escaping (URL?) -> Void) {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.message = "Balance needs your permission to read \(browser.rawValue) data."
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: browserFolderPath(for: browser))
        guard panel.runModal() == .OK, let url = panel.url else { completion(nil); return }
        finishAccess(to: url, for: browser, completion: completion)
        #else
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        let delegate = DirectoryPickerDelegate { [weak self] url in
            guard let self else { completion(nil); return }
            self.pickerDelegate = nil
            guard let url else { completion(nil); return }
            self.finishAccess(to: url, for: browser, completion: completion)
        }
        pickerDelegate = delegate
        picker.delegate = delegate
        guard let presenter = Self.topViewController() else {
            pickerDelegate = nil; completion(nil); return
        }
        presenter.present(picker, animated: true)
        #endif
    }

    private func finishAccess(to url: URL, for browser: ImportBrowser,
                              completion: @escaping (URL?) -> Void) {
        guard url.startAccessingSecurityScopedResource() else { completion(nil); return }
        #if canImport(AppKit)
        let options: URL.BookmarkCreationOptions = .withSecurityScope
        #else
        let options: URL.BookmarkCreationOptions = .minimalBookmark
        #endif
        if let data = try? url.bookmarkData(options: options,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey(for: browser))
        }
        completion(url)
    }

    #if canImport(AppKit)
    private func browserFolderPath(for browser: ImportBrowser) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch browser {
        case .chrome: return "\(home)/Library/Application Support/Google/Chrome"
        case .edge: return "\(home)/Library/Application Support/Microsoft Edge"
        case .firefox: return "\(home)/Library/Application Support/Firefox"
        }
    }
    #else
    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif

    func release(_ url: URL) { url.stopAccessingSecurityScopedResource() }
}

#if canImport(UIKit)
private final class DirectoryPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void
    init(completion: @escaping (URL?) -> Void) { self.completion = completion }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls.first)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completion(nil) }
}
#endif
