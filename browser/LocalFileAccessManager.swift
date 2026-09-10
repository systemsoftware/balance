import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
internal import UniformTypeIdentifiers
#endif

final class LocalFileAccessManager {
    static let shared = LocalFileAccessManager()
    private let defaultsKey = "localFileBookmarks_v1"
    private var activeBookmarks: [URL] = []
    private var powerboxPaths: Set<String> = []
    #if canImport(UIKit)
    private var pickerDelegate: LocalDirectoryPickerDelegate?
    #endif
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
        #if canImport(AppKit)
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
        #else
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.directoryURL = suggestedDirectory

        let delegate = LocalDirectoryPickerDelegate { [weak self] url in
            guard let self else {
                completion(nil)
                return
            }
            self.pickerDelegate = nil
            guard let url else {
                completion(nil)
                return
            }
            self.storeBookmark(url: url)
            completion(url)
        }
        pickerDelegate = delegate
        picker.delegate = delegate

        guard let presenter = Self.topViewController() else {
            pickerDelegate = nil
            completion(nil)
            return
        }
        presenter.present(picker, animated: true)
        #endif
    }
    private func storeBookmark(url: URL) {
        #if canImport(AppKit)
        let options: URL.BookmarkCreationOptions = .withSecurityScope
        #else
        let options: URL.BookmarkCreationOptions = .minimalBookmark
        #endif
        guard let data = try? url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        if url.startAccessingSecurityScopedResource() { activeBookmarks.append(url) }
        var saved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String:Data] ?? [:]
        saved[url.path] = data
        UserDefaults.standard.set(saved, forKey: defaultsKey)
    }
    private func restoreBookmarks() {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String:Data] else { return }
        for (_,data) in saved {
            var isStale = false
            #if canImport(AppKit)
            let options: URL.BookmarkResolutionOptions = .withSecurityScope
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            guard let url = try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale), !isStale else { continue }
            if url.startAccessingSecurityScopedResource() { activeBookmarks.append(url) }
        }
    }

    #if canImport(UIKit)
    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    #endif
}

#if canImport(UIKit)
private final class LocalDirectoryPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}
#endif
