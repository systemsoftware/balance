import SwiftUI
import WebKit
internal import Combine
import ZIPFoundation
import CoreLocation
import AuthenticationServices
import UserNotifications

private enum DownloadFilenameResolver {
    private static let extensionsByMIMEType: [String: String] = [
        "application/zip": "zip",
        "application/x-zip-compressed": "zip",
        "application/x-apple-diskimage": "dmg",
        "application/x-7z-compressed": "7z",
        "application/vnd.rar": "rar",
        "application/x-rar-compressed": "rar",
        "application/x-tar": "tar",
        "application/gzip": "gz",
        "application/x-gzip": "gz",
        "application/x-bzip2": "bz2"
    ]

    static func filename(
        linkFilename: String?,
        suggestedFilename: String,
        response: URLResponse
    ) -> String {
        let linkFilename = linkFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestedFilename = suggestedFilename.trimmingCharacters(in: .whitespacesAndNewlines)

        var filename: String
        if let linkFilename, !linkFilename.isEmpty {
            filename = linkFilename
        } else if !suggestedFilename.isEmpty, suggestedFilename != "download" {
            filename = suggestedFilename
        } else if let lastComponent = response.url?.lastPathComponent, !lastComponent.isEmpty {
            filename = lastComponent
        } else {
            filename = "download"
        }

        // A site's `download` attribute or Content-Disposition header can label a ZIP
        // as an .app. Finder then tries to launch the ZIP bytes as an application.
        // For archive formats, the response MIME type is the reliable extension.
        if let mimeType = response.mimeType?.lowercased(),
           let expectedExtension = extensionsByMIMEType[mimeType],
           (filename as NSString).pathExtension.lowercased() != expectedExtension {
            filename = (filename as NSString).deletingPathExtension + "." + expectedExtension
        }

        return (filename as NSString).lastPathComponent
    }
}


final class BrowserState: NSObject, ObservableObject, WKWebExtensionTab {
    @Published var tabID: String = ""
    @Published var webView: WKWebView?
    weak var underlyingWebView: WKWebView?

    @Published var url: URL?
    @Published private(set) var navigationRevision: UInt = 0
    @Published var title: String = ""
    @Published var customTitle: String? = nil
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var favicon: NSImage?
    var preloadedWebView: WKWebView?
    @Published var isFindBarVisible: Bool = false
    @Published var findQuery: String = ""
    @Published var findMatchCount: Int = 0
    @Published var isAudioMuted: Bool = false
    @Published var isSleeping: Bool = false
    var isPrivateBrowsing: Bool = false
    var shouldAnimateTabInsertion: Bool = false

    @Published var scrollX: Int = 0
    @Published var scrollY: Int = 0
    @Published var spaceIndex: Int = 0
    var restoredScrollX: Int?
    var restoredScrollY: Int?
    @Published var serverTrust: SecTrust?
    @Published var failedToLoad = false
    var lastHighlightedQuery: String = ""

    init(initialURL: URL? = nil) {
        self.url = initialURL
        super.init()
    }

    
    // MARK: - WKWebExtensionTab
    
    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        WebExtensionManager.shared.window
    }
    
    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        self.webView ?? self.underlyingWebView
    }
    
    func title(for context: WKWebExtensionContext) -> String? {
        self.title
    }
    
    func url(for context: WKWebExtensionContext) -> URL? {
        self.url ?? self.underlyingWebView?.url
    }
    
    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool {
        !self.isLoading
    }
    
    func isPinned(for context: WKWebExtensionContext) -> Bool { false }
    func isReaderModeAvailable(for context: WKWebExtensionContext) -> Bool { false }
    func isReaderModeActive(for context: WKWebExtensionContext) -> Bool { false }
    func isPlayingAudio(for context: WKWebExtensionContext) -> Bool { false }
    func isMuted(for context: WKWebExtensionContext) -> Bool { self.isAudioMuted }
    func size(for context: WKWebExtensionContext) -> CGSize {
        (webView ?? underlyingWebView)?.frame.size ?? .zero
    }
    func zoomFactor(for context: WKWebExtensionContext) -> Double { Double(zoomLevel) }
    
    func toggleMute() {
        isAudioMuted.toggle()
        let js = "document.querySelectorAll('video, audio').forEach(function(element) { element.muted = \(isAudioMuted ? "true" : "false"); });"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    @Published var zoomLevel: CGFloat = 1.0
    
    
    func applyZoom() {
        let zoom = min(2.0, max(0.5, zoomLevel))
        zoomLevel = zoom

        // Use WebKit's native zoom so the whole page (including fixed elements)
        // is scaled. The old body.style.zoom implementation was immediately
        // overwritten by BrowserWebView's per-site zoom synchronization.
        (webView ?? underlyingWebView)?.pageZoom = zoom

        if let host = (webView ?? underlyingWebView)?.url?.host ?? url?.host {
            SitePermissionStore.shared.setZoomLevel(
                for: host,
                value: Int((zoom * 100).rounded())
            )
        }
    }

    func applyTranslations(_ translations: [String]) async {
        guard let data = try? JSONSerialization.data(
            withJSONObject: translations
        ),
        let json = String(data: data, encoding: .utf8) else {
            return
        }

        let javascript = """
        const translations = \(json);

        const walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_TEXT
        );

        let nodes = [];

        while (walker.nextNode()) {
            const node = walker.currentNode;

            if (node.textContent.trim().length > 0) {
                nodes.push(node);
            }
        }

        nodes.forEach((node, index) => {
            if (translations[index] !== undefined) {
                node.textContent = translations[index];
            }
        });
        """

        do {
            try await webView?.evaluateJavaScript(javascript)
        } catch {
            print("Failed to apply translations:", error)
        }
    }

    @MainActor
    func getBackground() async -> NSColor {
        do {
            let result = try await webView?.evaluateJavaScript("window.getComputedStyle(document.body).backgroundColor")
            guard let rgbString = result as? String,
                  let nsColor = NSColor.from(rgbString: rgbString) else {
                return .gray
            }
            return nsColor.alphaComponent == 0 ? NSColor.white : nsColor
        } catch {
            return .gray
        }
    }
    
    public func zoomIn() {
        zoomLevel = min(2.0, (zoomLevel * 10).rounded() / 10 + 0.1)
        applyZoom()
    }

    public func zoomOut() {
        zoomLevel = max(0.5, (zoomLevel * 10).rounded() / 10 - 0.1)
        applyZoom()
    }

    public func resetZoom() {
        zoomLevel = 1.0
        applyZoom()
    }
    
    var hasCleanedUp: Bool = false
    
    deinit { print("🗑️ BrowserState deinit: \(tabID)") }
    
    func cleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        
        let manager = WebExtensionManager.shared
        manager.allTabs.remove(self)
        
        let webView = self.webView ?? self.preloadedWebView ?? self.underlyingWebView
        
        if let webView {
            if let coordinator = webView.navigationDelegate as? BrowserWebView.Coordinator {
                coordinator.observers.removeAll()
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "installExtension")
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "scrollObserver")
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "balanceLocation")
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "autofillRequest")
                webView.configuration.userContentController.removeAllScriptMessageHandlers()
                webView.configuration.userContentController.removeAllUserScripts()
                
                // The WKWebExtensionController lives in a global singleton and holds
                // its delegate strongly. Nil it here so the Coordinator can be
                // deallocated and doesn't keep the WKWebView context alive.
                coordinator.locationManager?.stopUpdatingLocation()
                coordinator.locationManager?.delegate = nil
                coordinator.locationManager = nil
            }
            
            if let controller = webView.configuration.webExtensionController {
                controller.didCloseTab(self)
                // We should NOT set controller.delegate = nil because the controller is shared
                // across all tabs in this profile context. Setting it to nil breaks extensions for others!
            }
            
            // Instantly clear the document memory before destroying the view.
            webView.evaluateJavaScript("document.write(''); document.close();") { _, _ in }
            
            // Stop loading and break all delegate references.
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.removeFromSuperview()
            
            // Break BrowserWKWebView's strong reference to BrowserState.
            if let customWebView = webView as? BrowserWKWebView {
                customWebView.state = nil
                customWebView.downloadStore = nil
            }
        }
        
        self.webView = nil
        self.preloadedWebView = nil
        self.underlyingWebView = nil
    }
}

// MARK: - Browser Window

final class BrowserWindow: NSObject, WKWebExtensionWindow {
    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        WebExtensionManager.shared.allTabs.filter { !$0.isPrivateBrowsing }
    }
    
    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        WebExtensionManager.shared.activeTab
    }
    
    func windowType(for context: WKWebExtensionContext) -> WKWebExtension.WindowType { .normal }
    func windowState(for context: WKWebExtensionContext) -> WKWebExtension.WindowState { .normal }
    func setWindowState(_ state: WKWebExtension.WindowState, for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) { completionHandler(nil) }
    func isPrivate(for context: WKWebExtensionContext) -> Bool { false }
    
    func screenFrame(for context: WKWebExtensionContext) -> CGRect {
        NSScreen.main?.frame ?? .zero
    }
    
    func frame(for context: WKWebExtensionContext) -> CGRect {
        NSApp.mainWindow?.frame ?? .zero
    }
    
    func setFrame(_ frame: CGRect, for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) { completionHandler(nil) }
    func focus(for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        completionHandler(nil)
    }
    func close(for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) { completionHandler(nil) }
    
}

extension BrowserState {
    func attach(_ webView: WKWebView) {
        self.webView = webView
        self.hasCleanedUp = false
    }

    func navigate(to url: URL?) {
        self.url = url
        navigationRevision &+= 1
    }
    
    func find(_ query: String, forward: Bool = true) {
        guard !query.isEmpty else {
            clearFind()
            return
        }
        if query != lastHighlightedQuery {
            highlightAll(query)
            lastHighlightedQuery = query
        }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.caseSensitive = false
        config.wraps = true
        webView?.find(query, configuration: config) { [weak self] result in
            DispatchQueue.main.async {
                self?.findMatchCount = result.matchFound ? 1 : 0
            }
        }
    }


    func clearFind() {
        findMatchCount = 0
        lastHighlightedQuery = ""
        clearHighlights()
        webView?.find("", configuration: WKFindConfiguration()) { _ in }
    }
    
    func highlightAll(_ query: String) {
        guard !query.isEmpty else {
            clearHighlights()
            return
        }

        // JSON-encode the query string to produce a safe JS string literal,
        // preventing injection when query contains quotes, backslashes, or newlines.
        guard let queryData = try? JSONEncoder().encode(query),
              let queryJSON = String(data: queryData, encoding: .utf8) else { return }

        let js = """
        (function() {
            const query = \(queryJSON);
            if (!query) {
                if (typeof CSS !== 'undefined' && CSS.highlights) {
                    CSS.highlights.delete('__find_highlight');
                }
                return 0;
            }

            if (typeof CSS === 'undefined' || !CSS.highlights) {
                return 0;
            }

            // Ensure our custom style rule is added to the document
            const styleId = '__find_highlight_style';
            let styleEl = document.getElementById(styleId);
            if (!styleEl) {
                styleEl = document.createElement('style');
                styleEl.id = styleId;
                styleEl.textContent = `
                    ::highlight(__find_highlight) {
                        background-color: #FFFFB3 !important;
                        color: #000000 !important;
                    }
                    ::selection {
                        background-color: #FFFF00 !important;
                        color: #000000 !important;
                    }
                `;
                (document.head || document.documentElement).appendChild(styleEl);
            }

            if (!document.body) return 0;

            const walker = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_TEXT,
                null
            );

            const ranges = [];
            let node;
            const queryLower = query.toLowerCase();
            const queryLength = query.length;
            const maxMatches = 5000;

            while ((node = walker.nextNode())) {
                const parentTagName = node.parentNode ? node.parentNode.tagName : '';
                if (parentTagName === 'SCRIPT' || parentTagName === 'STYLE' || parentTagName === 'NOSCRIPT') {
                    continue;
                }

                const text = node.nodeValue;
                const lower = text.toLowerCase();
                let idx = 0;
                while ((idx = lower.indexOf(queryLower, idx)) !== -1) {
                    if (ranges.length >= maxMatches) {
                        break;
                    }
                    const range = document.createRange();
                    range.setStart(node, idx);
                    range.setEnd(node, idx + queryLength);
                    ranges.push(range);
                    idx += queryLength;
                }
                if (ranges.length >= maxMatches) {
                    break;
                }
            }

            const highlight = new Highlight(...ranges);
            CSS.highlights.set('__find_highlight', highlight);
            return ranges.length;
        })()
        """

        webView?.evaluateJavaScript(js) { result, _ in
            if let count = result as? Int {
                print("Highlighted \(count) matches")
            }
        }
    }

    func clearHighlights() {
        let js = """
        (function() {
            if (typeof CSS !== 'undefined' && CSS.highlights) {
                CSS.highlights.delete('__find_highlight');
            }
            const styleEl = document.getElementById('__find_highlight_style');
            if (styleEl) {
                styleEl.remove();
            }
            // Fallback: Clear any legacy DOM highlights if they existed
            document.querySelectorAll('mark.__find_highlight').forEach(el => {
                el.replaceWith(...el.childNodes);
            });
            document.normalize();
        })()
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}

final class BrowserWKWebView: WKWebView {
    
    var downloadStore: DownloadStore?
    var state: BrowserState?
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if let state = state, result {
            let manager = WebExtensionManager.shared
            manager.activeTab = state.isPrivateBrowsing ? nil : state
            if !state.isPrivateBrowsing,
               let extController = self.configuration.webExtensionController {
                extController.didActivateTab(state)
            }
        }
        return result
    }
    
    deinit { print("🗑️ BrowserWKWebView deinit") }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
            print("custom menu is finally firing!")
        
            menu.addItem(.separator())
            
            let point = convert(event.locationInWindow, from: nil)
            let pointValue = NSValue(point: point)

            var isDownloadable = false
        
     //        var isLink = false
        
            var downloadType = ""
        
            for item in menu.items {
                let id = item.identifier?.rawValue ?? ""
                let actionStr = item.action.map { String(describing: $0) } ?? ""
                
                print(id)
                
                if id == "WKMenuItemIdentifierDownloadImage" ||
                   id == "WKMenuItemIdentifierDownloadLinkedFile" ||
                   actionStr.lowercased().contains("downloadimage") ||
                   actionStr.lowercased().contains("downloadlinkedfile") {
                    
                    item.isHidden = true
                    isDownloadable = true
                    downloadType = id
                }
                if id.contains("WKMenuItemIdentifierOpenLinkInNewWindow") {
                    item.title = "Open in New Tab"
                    item.target = self
                    item.action = #selector(openInNewTab(_:))
                    item.representedObject = pointValue
          //          isLink = true
                }
                
                if id.contains("WKMenuItemIdentifierOpenImageInNewWindow") {
                    item.title = "Open Image in New Tab"
                    item.target = self
                    item.action = #selector(openInNewTab(_:))
                    item.representedObject = pointValue
                }
            }

        menu.addItem(.separator())

            // 2. Add custom Download button if applicable
            if isDownloadable {
                let item = NSMenuItem(title: "Download \(downloadType == "WKMenuItemIdentifierDownloadImage" ? "Image" : "Linked File")", action: #selector(manualDownload(_:)), keyEquivalent: "", )
                item.target = self
                
                item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Download")
                
                // Store the click point instead of blocking the main thread with hitTestURL!
                item.representedObject = pointValue
                
                menu.addItem(item)
            } else {
                print("Not a downloadable link or image")
            }
        }
    

    
    @objc func openInNewTab(_ sender: NSMenuItem) {
        guard let pointValue = sender.representedObject as? NSValue else { return }
        let point = pointValue.pointValue

        evaluateJavaScript("""
        (function() {
            let el = document.elementFromPoint(\(point.x), \(point.y));
            if (!el) return null;
            if (el.tagName === 'IMG' && el.src) return el.src;
            let a = el.closest('a');
            return a ? a.href : null;
        })()
        """) { value, _ in
            guard let urlString = value as? String, let url = URL(string: urlString) else { return }
            DispatchQueue.main.async {
                createNewTab(with: url, inBackground: true)
            }
        }
    }
    
 
    @objc func manualDownload(_ sender: NSMenuItem) {
        guard let pointValue = sender.representedObject as? NSValue else { return }
        let point = pointValue.pointValue

        evaluateJavaScript("""
        (function() {
            let el = document.elementFromPoint(\(point.x), \(point.y));
            if (!el) return null;
            if (el.tagName === 'IMG' && el.src) return { url: el.src, name: el.getAttribute('download') || '' };
            let a = el.closest('a');
            return a ? { url: a.href, name: a.getAttribute('download') || '' } : null;
        })()
        """) { value, _ in
            guard let dict = value as? [String: String], let urlString = dict["url"], let url = URL(string: urlString) else { return }
            let name = dict["name"] ?? ""
            let request = URLRequest(url: url)
            Task { @MainActor in
                let download = await self.startDownload(using: request)
                if let coordinator = self.navigationDelegate as? BrowserWebView.Coordinator {
                    coordinator.downloads.insert(download)
                    DockProgressManager.shared.add(download: download)
                    if !name.isEmpty {
                        coordinator.downloadTitles[download] = name
                    }
                    download.delegate = coordinator
                }
            }
        }
    }
        
    @objc func goBackAction() { goBack() }
    @objc func goForwardAction() { goForward() }
    @objc func reloadAction() { reload() }

    @objc func inspectElement() {
        evaluateJavaScript("inspect(document.activeElement)")
    }
}

// MARK: - Error Pages

enum BrowserErrorKind {
    case offline
    case cannotFindHost
    case cannotConnect
    case timedOut
    case sslError
    case generic(String)
}

enum ErrorPageBuilder {

    /// Custom scheme used by the "Try Again" button so we can intercept it
    /// in decidePolicyFor and re-issue the real request.
    static let retryScheme = "balance-error-retry"

    /// Returns nil for errors that should NOT show an error page — most importantly
    /// NSURLErrorCancelled (-999), which fires constantly during normal fast navigation
    /// (e.g. the user typed a new URL before the old one finished, or a redirect
    /// superseded the current load). Showing an error page for those would be wrong.
    static func classify(_ error: NSError) -> BrowserErrorKind? {
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return nil
        }
        // WebKitErrorDomain "frame load interrupted" (102) also happens for legitimate
        // things like downloads and plugin handoffs — ignore it too.
        if error.domain == "WebKitErrorDomain" && error.code == 102 {
            return nil
        }

        guard error.domain == NSURLErrorDomain else {
            return .generic(error.localizedDescription)
        }

        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .offline
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return .cannotFindHost
        case NSURLErrorCannotConnectToHost:
            return .cannotConnect
        case NSURLErrorTimedOut:
            return .timedOut
        case NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateNotYetValid,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorClientCertificateRejected:
            return .sslError
        default:
            return .generic(error.localizedDescription)
        }
    }

    static func html(for kind: BrowserErrorKind, url: URL?) -> String {
            let host = url?.host ?? url?.absoluteString ?? "this site"
            let title: String
            let message: String
            let icon: String

            switch kind {
            case .offline:
                title = "No Internet Connection"
                message = "Check your connection and try again."
                icon = Self.iconOffline
            case .cannotFindHost:
                title = "Can't Find Server"
                message = "Balance can't find the server at \(escape(host))."
                icon = Self.iconWarning
            case .cannotConnect:
                title = "Can't Connect to Server"
                message = "The server at \(escape(host)) may be temporarily down."
                icon = Self.iconWarning
            case .timedOut:
                title = "Request Timed Out"
                message = "The connection to \(escape(host)) timed out."
                icon = Self.iconWarning
            case .sslError:
                title = "Connection Not Private"
                message = "Balance can't verify the identity of \(escape(host))."
                icon = Self.iconLock
            case .generic(let msg):
                title = "Something Went Wrong"
                message = escape(msg)
                icon = Self.iconWarning
            }

            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(escape(title))</title>
            <style>
            :root { color-scheme: light dark; }
            * { box-sizing: border-box; }
            html, body {
                margin: 0; height: 100%;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                background: Canvas; color: CanvasText;
            }
            body { display: flex; align-items: center; justify-content: center; padding: 24px; }
            .wrap { max-width: 360px; }
            .icon { width: 30px; height: 30px; margin-bottom: 16px; opacity: 0.5; }
            .icon svg { width: 100%; height: 100%; }
            h1 { font-size: 17px; font-weight: 600; margin: 0 0 6px; letter-spacing: -0.2px; }
            p { font-size: 13px; opacity: 0.55; line-height: 1.45; margin: 0 0 20px; }
            button {
                font: inherit; font-size: 13px; font-weight: 500; padding: 7px 16px;
                border-radius: 6px; border: 1px solid; border-color: color-mix(in srgb, CanvasText 15%, transparent);
                background: transparent; color: CanvasText; cursor: pointer;
            }
            button:hover { background: color-mix(in srgb, CanvasText 6%, transparent); }
            button:active { background: color-mix(in srgb, CanvasText 12%, transparent); }
            .url { font-size: 11px; opacity: 0.35; margin-top: 16px; word-break: break-all; }
            </style>
            </head>
            <body>
            <div class="wrap">
                <div class="icon">\(icon)</div>
                <h1>\(escape(title))</h1>
                <p>\(message)</p>
                <button onclick="location.href='\(retryScheme)://retry'">Try Again</button>
                \(url.map { "<div class=\"url\">\(escape($0.absoluteString))</div>" } ?? "")
            </div>
            </body>
            </html>
            """
        }

        private static let iconWarning = """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 9v4M12 16.5h.01M10.3 3.9 2.6 17.5a1.8 1.8 0 0 0 1.56 2.7h15.7a1.8 1.8 0 0 0 1.56-2.7L13.7 3.9a1.8 1.8 0 0 0-3.14 0Z" stroke-linecap="round" stroke-linejoin="round"/></svg>
        """

        private static let iconOffline = """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2 8.5C7 4 17 4 22 8.5M5.5 12c3.5-3 9.5-3 13 0M9 15.5c1.7-1.3 4.3-1.3 6 0" stroke-linecap="round"/><circle cx="12" cy="19" r="1"/></svg>
        """

        private static let iconLock = """
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3" stroke-linecap="round"/></svg>
        """


    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

struct BrowserWebView: NSViewRepresentable {
    let request: URLRequest
    @ObservedObject var state: BrowserState
    let navigationRevision: UInt
    @ObservedObject var permissions = SitePermissionStore.shared
    
    var priv: Bool = false
    var profile = ""
    var userAgent: String = ""

    init(
        request: URLRequest,
        state: BrowserState,
        navigationRevision: UInt? = nil,
        priv: Bool = false,
        profile: String = "",
        userAgent: String = ""
    ) {
        self.request = request
        self.state = state
        self.navigationRevision = navigationRevision ?? state.navigationRevision
        self.priv = priv
        self.profile = profile
        self.userAgent = userAgent
    }

    func makeCoordinator() -> Coordinator {
        // The coordinator belongs to the live page, not its SwiftUI mount.
        // Keep navigation, script callbacks and content-blocker state intact.
        if let coordinator = state.webView?.navigationDelegate as? Coordinator {
            return coordinator
        }
        return Coordinator(state: state, profile: profile, isPrivate: priv)
    }

    func makeNSView(context: Context) -> WKWebView {
        if let webView = state.webView,
           webView.navigationDelegate === context.coordinator {
            return webView
        }
        // A tab that is not visible parks its WKWebView in BrowserState. Reuse
        // it when the tab becomes active again so removing the inactive SwiftUI
        // control tree does not reload or discard the page.
        if let preloaded = (state.webView as? BrowserWKWebView)
            ?? (state.preloadedWebView as? BrowserWKWebView) {
            let host = request.url?.host ?? "default"
            preloaded.downloadStore = DownloadStore(profile: profile)
            if !userAgent.isEmpty {
                preloaded.customUserAgent = userAgent
            }
            let defaultZoom = SitePermissionStore.shared.zoomLevel(for: host)
            preloaded.pageZoom = CGFloat(defaultZoom) / 100.0
            preloaded.state = state
            preloaded.navigationDelegate = context.coordinator
            preloaded.uiDelegate = context.coordinator

            let userContentController = preloaded.configuration.userContentController
            for name in Self.scriptMessageHandlerNames {
                userContentController.removeScriptMessageHandler(forName: name)
                userContentController.add(context.coordinator, name: name)
            }
            
            DispatchQueue.main.async {
                state.attach(preloaded)
            }
            
            context.coordinator.observers = [
                preloaded.observe(\.estimatedProgress, options: .new) { [weak state] webView, _ in
                    DispatchQueue.main.async {
                        state?.progress = webView.estimatedProgress
                        state?.isLoading = webView.isLoading
                    }
                },
                preloaded.observe(\.title, options: .new) { [weak state] webView, _ in
                    DispatchQueue.main.async {
                        if state?.customTitle == nil { state?.title = webView.title ?? "Page" }
                    }
                },
                preloaded.observe(\.url, options: .new) { [weak state] webView, _ in
                    DispatchQueue.main.async {
                        state?.url = webView.url
                        if let extController = webView.configuration.webExtensionController, let state = state {
                            extController.didChangeTabProperties([.URL], for: state)
                        }
                    }
                },
                preloaded.observe(\.canGoBack, options: .new) { [weak state] webView, _ in
                    DispatchQueue.main.async { state?.canGoBack = webView.canGoBack }
                },
                preloaded.observe(\.canGoForward, options: .new) { [weak state] webView, _ in
                    DispatchQueue.main.async { state?.canGoForward = webView.canGoForward }
                },
                preloaded.observe(\.serverTrust, options: [.initial, .new]) { [weak state] webView, _ in
                    DispatchQueue.main.async { state?.serverTrust = webView.serverTrust }
                }
            ]
            
            if !state.isPrivateBrowsing {
                let manager = WebExtensionManager.shared
                let wasNewTab = manager.allTabs.insert(state).inserted
                if let extController = preloaded.configuration.webExtensionController {
                    manager.openWindowIfNeeded(for: extController)
                    if wasNewTab {
                        extController.didOpenTab(state)
                    }
                    extController.didActivateTab(state)
                }
            }
            
            context.coordinator.handledNavigationRevision = navigationRevision
            state.preloadedWebView = nil
            return preloaded
        }

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "fullScreenEnabled")
        if #available(macOS 12.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Media configurations useful for DRM / FairPlay streams
        let host = request.url?.host ?? "default"
        
        let autoplaySetting = SitePermissionStore.shared.setting(for: host, type: "autoplay", defaultState: .allow)
        if autoplaySetting == .allow {
            config.mediaTypesRequiringUserActionForPlayback = []
        } else {
            config.mediaTypesRequiringUserActionForPlayback = .all
        }
        
        let notificationsSetting = SitePermissionStore.shared.mediaPermission(for: host, type: "notifications")
        let notifSettingStr = notificationsSetting == .allow ? "granted" : (notificationsSetting == .deny ? "denied" : "default")
        
        let notificationsJS = """
        (function() {
            let currentPermission = '\(notifSettingStr)';
            
            function MockNotification(title, options) {
                if (currentPermission !== 'granted') return;
                let msg = { title: title };
                if (options) {
                    msg.body = options.body;
                    msg.icon = options.icon;
                }
                window.webkit.messageHandlers.notificationShow.postMessage(msg);
            }
            
            Object.defineProperty(MockNotification, 'permission', {
                get: function() { return currentPermission; }
            });

            window.__balanceSetNotificationPermission = function(permission) {
                currentPermission = permission;
            };
            
            MockNotification.requestPermission = function(callback) {
                return new Promise((resolve) => {
                    if (currentPermission !== 'default') {
                        if (callback) callback(currentPermission);
                        resolve(currentPermission);
                        return;
                    }
                    
                    const callbackId = 'notif_' + Math.random().toString(36).substr(2, 9);
                    window['__balanceNotificationCallback_' + callbackId] = function(result) {
                        currentPermission = result;
                        if (callback) callback(result);
                        resolve(result);
                        delete window['__balanceNotificationCallback_' + callbackId];
                    };
                    
                    window.webkit.messageHandlers.notificationRequestPermission.postMessage({ id: callbackId });
                });
            };
            
            window.Notification = MockNotification;
        })();
        """
        let notifScript = WKUserScript(source: notificationsJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(notifScript)
        config.userContentController.add(context.coordinator, name: "notificationRequestPermission")
        config.userContentController.add(context.coordinator, name: "notificationShow")
        
        config.allowsAirPlayForMediaPlayback = true
        
        // Chrome Web Store integration
        config.userContentController.add(context.coordinator, name: "installExtension")
        
        let installedIDs = WebExtensionManager.shared.contexts.compactMap { context -> String? in
            for component in context.baseURL.pathComponents.reversed() {
                if component.count == 32 && component.allSatisfy({ $0.isLowercase && $0.isLetter }) {
                    return component
                }
            }
            return context.baseURL.lastPathComponent
        }
        let idsStr = installedIDs.map { "\"\($0)\"" }.joined(separator: ",")
        
        let cwsScript = """
        (function() {
            window.balanceInstalledExtensions = [\(idsStr)];
            if (!window.location.hostname.includes("chromewebstore.google.com")) return;
            let checkInterval = setInterval(() => {
                let buttons = Array.from(document.querySelectorAll('button'));
                let installBtn = buttons.find(b => {
                    let text = b.innerText.toLowerCase();
                    let aria = (b.getAttribute('aria-label') || "").toLowerCase();
                    if (text.includes("switch to chrome") || aria.includes("switch to chrome")) return false;
                    
                    return text.includes("available on chrome") || 
                           text.includes("add to chrome") ||
                           text.includes("install");
                });
                
                if (installBtn && !installBtn.hasAttribute('data-balance-injected')) {
                    let pathParts = window.location.pathname.split('/');
                    let extId = pathParts[pathParts.length - 1];
                    
                    if (extId && extId.length === 32) {
                        let newBtn = installBtn.cloneNode(true);
                        newBtn.setAttribute('data-balance-injected', 'true');
                        newBtn.disabled = false;
                        
                        let isInstalled = window.balanceInstalledExtensions.includes(extId);
                        
                        let spans = newBtn.querySelectorAll('span');
                        let textSpan = Array.from(spans).find(s => s.innerText.includes("Chrome") || s.innerText.includes("Install"));
                        
                        let btnText = isInstalled ? "Installed" : "Install in Balance";
                        
                        if (textSpan) {
                            textSpan.innerText = btnText;
                        } else {
                            newBtn.innerText = btnText;
                        }
                        
                        // Use inline interval to check if it gets installed dynamically
                        let checkDynamic = setInterval(() => {
                            if (window.balanceInstalledExtensions.includes(extId)) {
                                if (textSpan) textSpan.innerText = "Installed";
                                else newBtn.innerText = "Installed";
                                newBtn.style.backgroundColor = "#34C759";
                                newBtn.style.cursor = "default";
                                newBtn.disabled = true;
                                clearInterval(checkDynamic);
                            }
                        }, 500);
                        
                        newBtn.style.backgroundColor = isInstalled ? "#34C759" : "#007AFF"; 
                        newBtn.style.color = "white";
                        newBtn.style.opacity = "1";
                        newBtn.style.cursor = isInstalled ? "default" : "pointer";
                        newBtn.style.pointerEvents = "auto";
                        
                        installBtn.parentNode.replaceChild(newBtn, installBtn);
                        
                        if (!isInstalled) {
                            newBtn.addEventListener('click', (e) => {
                                e.preventDefault();
                                e.stopPropagation();
                                if (textSpan) textSpan.innerText = "Installing...";
                                else newBtn.innerText = "Installing...";
                                window.webkit.messageHandlers.installExtension.postMessage(extId);
                                
                                setTimeout(() => {
                                    if (textSpan) textSpan.innerText = "Installed";
                                    else newBtn.innerText = "Installed";
                                    newBtn.style.backgroundColor = "#34C759";
                                    if (!window.balanceInstalledExtensions.includes(extId)) {
                                        window.balanceInstalledExtensions.push(extId);
                                    }
                                }, 2000);
                            });
                        }
                    }
                }
                
                
                // Hide "Switch to Chrome" banners more aggressively
                let promos = document.querySelectorAll('*');
                for (let el of promos) {
                    if (el.children.length > 4) continue;
                    let text = (el.innerText || "").toLowerCase().trim();
                    if (text.includes("switch to chrome") || text.includes("download chrome") || text.includes("you need chrome")) {
                        let banner = el.closest('div[role="banner"]') || el.parentElement.parentElement;
                        if (banner && banner.style.display !== 'none' && banner.tagName !== 'BODY') {
                            banner.style.display = 'none';
                        }
                    }
                }
            }, 1000);
        })();
        """
        let script = WKUserScript(source: cwsScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        
        let scrollObserverScript = """
        window.addEventListener('scroll', () => {
            clearTimeout(window.scrollTimeout);
            window.scrollTimeout = setTimeout(() => {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.scrollObserver) {
                    window.webkit.messageHandlers.scrollObserver.postMessage({x: window.scrollX, y: window.scrollY});
                }
            }, 250);
        });
        """
        let scrollScript = WKUserScript(source: scrollObserverScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(scrollScript)
        config.userContentController.add(context.coordinator, name: "scrollObserver")
        
        let locationScript = """
        (function() {
            let locationCallbacks = {};
            let watchCallbacks = {};
            let callbackIdCounter = 0;

            navigator.geolocation.getCurrentPosition = function(success, error, options) {
                const state = prompt("BALANCE_INTERNAL_LOCATION_CHECK");
                if (state === 'Deny') {
                    if (error) error({ code: 1, message: 'User denied Geolocation' });
                    return;
                }
                
                const id = ++callbackIdCounter;
                locationCallbacks[id] = { success: success, error: error };
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.balanceLocation) {
                    window.webkit.messageHandlers.balanceLocation.postMessage({ type: 'get', id: id });
                }
            };

            navigator.geolocation.watchPosition = function(success, error, options) {
                const state = prompt("BALANCE_INTERNAL_LOCATION_CHECK");
                if (state === 'Deny') {
                    if (error) error({ code: 1, message: 'User denied Geolocation' });
                    return 0;
                }
                const id = ++callbackIdCounter;
                watchCallbacks[id] = { success: success, error: error };
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.balanceLocation) {
                    window.webkit.messageHandlers.balanceLocation.postMessage({ type: 'watch', id: id });
                }
                return id;
            };

            navigator.geolocation.clearWatch = function(id) {
                delete watchCallbacks[id];
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.balanceLocation) {
                    window.webkit.messageHandlers.balanceLocation.postMessage({ type: 'clear', id: id });
                }
            };

            window.__balanceLocationCallback = function(id, errCode, lat, lng, acc) {
                const cb = locationCallbacks[id] || watchCallbacks[id];
                if (!cb) return;
                
                if (errCode === 0) {
                    if (cb.success) {
                        cb.success({
                            coords: { latitude: lat, longitude: lng, accuracy: acc },
                            timestamp: Date.now()
                        });
                    }
                } else {
                    if (cb.error) cb.error({ code: errCode, message: 'Location error' });
                }
                
                if (locationCallbacks[id]) {
                    delete locationCallbacks[id];
                }
            };
        })();
        """
        let locScript = WKUserScript(source: locationScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(locScript)
        config.userContentController.add(context.coordinator, name: "balanceLocation")
        
        
        let dntEnabled = Config.sharedDefaults?.bool(forKey: "doNotTrack") ?? false
        if dntEnabled {
            let dntScript = WKUserScript(source: "Object.defineProperty(navigator, 'doNotTrack', { get: function() { return '1'; } });", injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(dntScript)
        }
        
        let autofillScript = """
        document.addEventListener('focusin', function(e) {
            let el = e.target;
            if (el.tagName === 'INPUT' && (el.type === 'password' || el.type === 'text' || el.type === 'email')) {
                // Check if it's likely a login form
                let form = el.closest('form');
                let hasPassword = false;
                if (form) {
                    let inputs = form.querySelectorAll('input');
                    for (let input of inputs) {
                        if (input.type === 'password') {
                            hasPassword = true;
                            break;
                        }
                    }
                } else if (el.type === 'password') {
                    hasPassword = true;
                }
                
                if (hasPassword) {
                    let rect = el.getBoundingClientRect();
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.autofillRequest) {
                        window.webkit.messageHandlers.autofillRequest.postMessage({
                            x: rect.x,
                            y: rect.y,
                            width: rect.width,
                            height: rect.height,
                            type: el.type
                        });
                    }
                }
            }
        });
        
        window.__balanceAutofill = function(username, password) {
            let passwordInputs = document.querySelectorAll('input[type="password"]');
            for (let passwordInput of passwordInputs) {
                let scope = passwordInput.closest('form') || document;
                let textInputs = scope.querySelectorAll('input:not([type="password"]):not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"])');
                let usernameInput = null;
                if (textInputs.length > 0) {
                    for (let input of textInputs) {
                        if (input.compareDocumentPosition(passwordInput) & Node.DOCUMENT_POSITION_FOLLOWING) {
                            usernameInput = input;
                        }
                    }
                    if (!usernameInput) usernameInput = textInputs[0];
                }
                
                const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
                
                if (usernameInput && username && username !== "Unknown") {
                    nativeInputValueSetter.call(usernameInput, username);
                    usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
                    usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
                }
                if (password) {
                    nativeInputValueSetter.call(passwordInput, password);
                    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
                    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
                }
                return;
            }
        };
        
        window.__balanceGetFormValues = function() {
            let passwordInputs = document.querySelectorAll('input[type="password"]');
            for (let passwordInput of passwordInputs) {
                if (passwordInput.value) {
                    let scope = passwordInput.closest('form') || document;
                    let textInputs = scope.querySelectorAll('input:not([type="password"]):not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"])');
                    let usernameInput = null;
                    if (textInputs.length > 0) {
                        for (let input of textInputs) {
                            if (input.compareDocumentPosition(passwordInput) & Node.DOCUMENT_POSITION_FOLLOWING) {
                                usernameInput = input;
                            }
                        }
                        if (!usernameInput) usernameInput = textInputs[0];
                    }
                    
                    let username = (usernameInput && usernameInput.value) ? usernameInput.value : "Unknown";
                    return { username: username, password: passwordInput.value };
                }
            }
            return null;
        };
        """
        let afScript = WKUserScript(source: autofillScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(afScript)
        config.userContentController.add(context.coordinator, name: "autofillRequest")
        
        WebExtensionManager.shared.loadAllFromDisk()
        if !priv {
            WebExtensionManager.shared.activeTab = state
        }
        
        var profileContext = ""
        
        if priv {
            profileContext = "priv"
        } else if !profile.isEmpty {
            profileContext = "profile"
        }

        switch profileContext {

        case "priv":
            config.websiteDataStore = .nonPersistent()

        case "profile":
            // Guard against malformed profile UUID strings to avoid a force-unwrap crash.
            if let profileUUID = UUID(uuidString: profile) {
                config.websiteDataStore = WKWebsiteDataStore(forIdentifier: profileUUID)
            } else {
                config.websiteDataStore = .default()
            }
            
        default:
            config.websiteDataStore = .default()
        }
        
        let extensionControllerKey = profile
        if !priv {
            let controller = WebExtensionManager.shared.controller(for: extensionControllerKey)
            config.webExtensionController = controller
            config.webExtensionController?.delegate = WebExtensionManager.shared
        }

        let webView = BrowserWKWebView(frame: .zero, configuration: config)
        webView.downloadStore = DownloadStore(profile: profile)
        if !userAgent.isEmpty {
            webView.customUserAgent = userAgent
        } else {
            webView.customUserAgent = DEFAULT_USER_AGENT
        }
        
        let defaultZoom = SitePermissionStore.shared.zoomLevel(for: host)
        webView.pageZoom = CGFloat(defaultZoom) / 100.0
        webView.state = state
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        state.underlyingWebView = webView

        DispatchQueue.main.async {
            state.attach(webView)
        }
        
        if !priv {
            let manager = WebExtensionManager.shared
            let extController = manager.controller(for: extensionControllerKey)
            manager.openWindowIfNeeded(for: extController)
            manager.allTabs.insert(state)
            extController.didOpenTab(state)
            extController.didActivateTab(state)
            manager.activeTab = state
        }

        context.coordinator.observers = [
            webView.observe(\.estimatedProgress, options: .new) { [weak state] webView, _ in
                DispatchQueue.main.async {
                    state?.progress = webView.estimatedProgress
                    state?.isLoading = webView.isLoading
                }
            },
            webView.observe(\.title, options: .new) { [weak state] webView, _ in
                DispatchQueue.main.async {
                    if state?.customTitle == nil { state?.title = webView.title ?? "Page" }
                }
            },
            webView.observe(\.url, options: .new) { [weak state] webView, _ in
                DispatchQueue.main.async {
                    state?.url = webView.url
                    if let extController = webView.configuration.webExtensionController, let state = state {
                        extController.didChangeTabProperties([.URL], for: state)
                    }
                }
            },
            webView.observe(\.canGoBack, options: .new) { [weak state] webView, _ in
                DispatchQueue.main.async { state?.canGoBack = webView.canGoBack }
            },
            webView.observe(\.canGoForward, options: .new) { [weak state] webView, _ in
                DispatchQueue.main.async { state?.canGoForward = webView.canGoForward }
            },
            webView.observe(\.serverTrust, options: [.initial, .new]) { [weak state] webView, _ in
                DispatchQueue.main.async { state?.serverTrust = webView.serverTrust }
            }
        ]
        
        webView.allowsBackForwardNavigationGestures = true
        
            let base = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let dir = base?.appendingPathComponent("ContentBlockers", isDirectory: true)
        
            let blockersEnabled = SitePermissionStore.shared.toggleState(for: host, type: "contentblockers", defaultState: .enabled) == .enabled
            context.coordinator.contentBlockersEnabled = blockersEnabled
            Self.configureContentBlockers(on: webView, enabled: blockersEnabled, directory: dir, reloadWhenReady: false, coordinator: context.coordinator)
        
        context.coordinator.handledNavigationRevision = navigationRevision
        if let url = request.url, url.isFileURL {
            let manager = LocalFileAccessManager.shared
            if let accessURL = manager.grantedAccessURL(for: url) {
                // Already have a cached bookmark or powerbox grant — load immediately.
                webView.loadFileURL(url, allowingReadAccessTo: accessURL)
            } else {
                // No existing grant: show NSOpenPanel so the user can pick the project
                // root. This is required for MAS sandbox compliance.
                let suggested = url.deletingLastPathComponent()
                Task { @MainActor in
                    manager.requestDirectoryAccess(suggestedDirectory: suggested) { accessURL in
                        guard let accessURL else { return }
                        webView.loadFileURL(url, allowingReadAccessTo: accessURL)
                    }
                }
            }
        } else {
            webView.load(request)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let host = nsView.url?.host ?? request.url?.host ?? "default"
        
        let siteZoom = SitePermissionStore.shared.zoomLevel(for: host)
        let targetZoom = CGFloat(siteZoom) / 100.0
        if nsView.pageZoom != targetZoom {
            nsView.pageZoom = targetZoom
        }
        if context.coordinator.state.zoomLevel != targetZoom {
            DispatchQueue.main.async {
                context.coordinator.state.zoomLevel = targetZoom
            }
        }
        
        let autoplaySetting = SitePermissionStore.shared.setting(for: host, type: "autoplay", defaultState: .allow)
        nsView.configuration.mediaTypesRequiringUserActionForPlayback = (autoplaySetting == .allow) ? [] : .all
        if autoplaySetting == .block {
            nsView.evaluateJavaScript("document.querySelectorAll('video, audio').forEach(function(v) { if (!v.paused) v.pause(); });", completionHandler: nil)
        }

        context.coordinator.syncNotificationPermission(in: nsView)

        let blockersEnabled = SitePermissionStore.shared.toggleState(for: host, type: "contentblockers", defaultState: .enabled) == .enabled
        if context.coordinator.contentBlockersEnabled != blockersEnabled {
            context.coordinator.contentBlockersEnabled = blockersEnabled
            let base = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base?.appendingPathComponent("ContentBlockers", isDirectory: true)
            Self.configureContentBlockers(on: nsView, enabled: blockersEnabled, directory: directory, reloadWhenReady: true, coordinator: context.coordinator)
        }

        if context.coordinator.handledNavigationRevision != navigationRevision {
            context.coordinator.handledNavigationRevision = navigationRevision
            if let url = request.url, url.isFileURL {
                let manager = LocalFileAccessManager.shared
                if let accessURL = manager.grantedAccessURL(for: url) {
                    // Already have a cached bookmark or powerbox grant — load immediately.
                    nsView.loadFileURL(url, allowingReadAccessTo: accessURL)
                } else {
                    // No existing grant: show NSOpenPanel so the user can pick the project
                    // root. This is required for MAS sandbox compliance.
                    let suggested = url.deletingLastPathComponent()
                    Task { @MainActor in
                        manager.requestDirectoryAccess(suggestedDirectory: suggested) { accessURL in
                            guard let accessURL else { return }
                            nsView.loadFileURL(url, allowingReadAccessTo: accessURL)
                        }
                    }
                }
            } else {
                nsView.load(request)
            }
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        let state = coordinator.state
        guard !state.hasCleanedUp else { return }

        // Only detach the native view from the inactive SwiftUI hierarchy.
        // Script handlers retain the coordinator so background redirects and
        // login callbacks continue working. cleanup() releases them on close.
        nsView.removeFromSuperview()
        if state.webView !== nsView {
            state.webView = nsView
        }
    }

    private static let scriptMessageHandlerNames = [
        "notificationRequestPermission",
        "notificationShow",
        "installExtension",
        "scrollObserver",
        "balanceLocation",
        "autofillRequest"
    ]

    private static func configureContentBlockers(
        on webView: WKWebView,
        enabled: Bool,
        directory: URL?,
        reloadWhenReady: Bool,
        coordinator: Coordinator
    ) {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()

        guard enabled, let directory else {
            if reloadWhenReady { webView.reload() }
            return
        }

        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            print("Error reading content blocker directory: \(error.localizedDescription)")
            if reloadWhenReady { webView.reload() }
            return
        }

        let group = DispatchGroup()
        for item in items {
            guard let json = try? String(contentsOf: item, encoding: .utf8),
                  let data = json.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                print("Content blocker contains invalid JSON: \(item.lastPathComponent)")
                continue
            }

            group.enter()
            let identifier = "dynamicRules-\(item.lastPathComponent)"
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: json
            ) { ruleList, error in
                defer { group.leave() }
                if let ruleList, coordinator.contentBlockersEnabled == true {
                    controller.add(ruleList)
                } else if let error {
                    print("Failed to compile \(item.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        if reloadWhenReady {
            group.notify(queue: .main) { [weak webView, weak coordinator] in
                guard coordinator?.contentBlockersEnabled == enabled else { return }
                webView?.reload()
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {
        
        var observers: [NSKeyValueObservation] = []
        let downloadStore: DownloadStore
        var locationManager: CLLocationManager?

        let state: BrowserState
        let isPrivate: Bool
        var downloads: Set<WKDownload> = []
        var handledNavigationRevision: UInt?
        var lastFailedURL: URL?
        var contentBlockersEnabled: Bool?
        let profile: String

        func syncNotificationPermission(in webView: WKWebView) {
            guard let host = webView.url?.host else { return }
            let state = SitePermissionStore.shared.mediaPermission(for: host, type: "notifications")
            let value = state == .allow ? "granted" : (state == .deny ? "denied" : "default")
            webView.evaluateJavaScript("window.__balanceSetNotificationPermission?.('\(value)')", completionHandler: nil)
        }

        init(state: BrowserState, profile: String, isPrivate: Bool) {
            self.state = state
            self.profile = profile
            self.isPrivate = isPrivate
            self.downloadStore = DownloadStore(profile: profile)
            super.init()
        }
        
        var activeLocationRequests: [(id: Int, isWatch: Bool)] = []
        
        
        func sendLocationToJS(id: Int, location: CLLocation) {
            let lat = location.coordinate.latitude
            let lng = location.coordinate.longitude
            let acc = location.horizontalAccuracy
            state.webView?.evaluateJavaScript("if (window.__balanceLocationCallback) window.__balanceLocationCallback(\(id), 0, \(lat), \(lng), \(acc));", completionHandler: nil)
        }
        
        func sendLocationErrorToJS(id: Int, errorCode: Int) {
            state.webView?.evaluateJavaScript("if (window.__balanceLocationCallback) window.__balanceLocationCallback(\(id), \(errorCode), 0, 0, 0);", completionHandler: nil)
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.last else { return }
            for req in activeLocationRequests {
                sendLocationToJS(id: req.id, location: loc)
            }
            activeLocationRequests.removeAll { !$0.isWatch }
            if activeLocationRequests.isEmpty {
                manager.stopUpdatingLocation()
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            for req in activeLocationRequests {
                sendLocationErrorToJS(id: req.id, errorCode: 2)
            }
            activeLocationRequests.removeAll()
            manager.stopUpdatingLocation()
        }
        

        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "installExtension", let extId = message.body as? String {
                guard message.frameInfo.isMainFrame,
                      message.frameInfo.securityOrigin.host == "chromewebstore.google.com",
                      extId.range(of: #"^[a-p]{32}$"#, options: .regularExpression) != nil else {
                    return
                }
                #if arch(arm64)
                let arch = "arm64"
                #else
                let arch = "x86-64"
                #endif
                let urlStr = "https://clients2.google.com/service/update2/crx?response=redirect&os=mac&arch=\(arch)&os_arch=\(arch)&nacl_arch=arm&prod=chromecrx&prodchannel=&prodversion=133.0.0.0&lang=en-US&acceptformat=crx2,crx3&x=id=\(extId)%26installsource=ondemand%26uc"
                
                if let url = URL(string: urlStr) {
                    CRXInstaller.install(fromRemote: url)
                }
            } else if message.name == "autofillRequest", let dict = message.body as? [String: Any] {
                guard message.frameInfo.isMainFrame else { return }
                guard let x = dict["x"] as? Double,
                      let y = dict["y"] as? Double,
                      let width = dict["width"] as? Double,
                      let height = dict["height"] as? Double else { return }
                
                DispatchQueue.main.async {
                    let host = message.frameInfo.securityOrigin.host.lowercased()
                    if let webView = self.state.webView, !host.isEmpty {
                        let rect = NSRect(x: x, y: y, width: width, height: height)
                        let credentials = PasswordManager.shared.credentials(for: host)
                        
                        let frameInfo = message.frameInfo
                        
                        AutofillPopoverManager.shared.show(relativeTo: rect, in: webView, domain: host, credentials: credentials) { [weak self = self] cred in
                            let pass = PasswordManager.shared.fetchPasswordData(for: cred.username, domain: host) ?? ""
                            
                            let credentialsArray = [cred.username, pass]
                            if let data = try? JSONSerialization.data(withJSONObject: credentialsArray),
                               let jsonStr = String(data: data, encoding: .utf8) {
                                let js = "window.__balanceAutofill(\(jsonStr)[0], \(jsonStr)[1]);"
                                self?.state.webView?.evaluateJavaScript(js, in: frameInfo, in: .page, completionHandler: { _ in })
                            }
                        } onSave: { [weak self = self] in
                            self?.state.webView?.evaluateJavaScript("window.__balanceGetFormValues()", in: frameInfo, in: .page) { result in
                                switch result {
                                case .success(let res):
                                    print("evaluateJavaScript result: \(String(describing: res))")
                                    if let dict = res as? [String: String], let u = dict["username"], let p = dict["password"] {
                                        print("Found username and password in JS, saving...")
                                        PasswordManager.shared.savePassword(username: u, passwordString: p, domain: host)
                                    } else {
                                        print("Failed to parse username and password from JS result")
                                    }
                                case .failure(let error):
                                    print("evaluateJavaScript error: \(error)")
                                }
                            }
                        }
                    }
                }
            } else if message.name == "scrollObserver", let dict = message.body as? [String: Any] {
                guard message.frameInfo.isMainFrame else { return }
                if let x = dict["x"] as? NSNumber, let y = dict["y"] as? NSNumber {
                    DispatchQueue.main.async {
                        self.state.scrollX = x.intValue
                        self.state.scrollY = y.intValue
                    }
                }
            } else if message.name == "balanceLocation", let dict = message.body as? [String: Any] {
                guard message.frameInfo.isMainFrame else { return }
                guard let type = dict["type"] as? String, let id = dict["id"] as? Int else { return }
                
                DispatchQueue.main.async {
                    if type == "clear" {
                        self.activeLocationRequests.removeAll { $0.id == id }
                        if self.activeLocationRequests.isEmpty {
                            self.locationManager?.stopUpdatingLocation()
                        }
                        return
                    }
                    
                    self.activeLocationRequests.append((id: id, isWatch: type == "watch"))
                    
                    if self.locationManager == nil {
                        self.locationManager = CLLocationManager()
                        self.locationManager?.delegate = self
                    }
                    self.locationManager?.requestWhenInUseAuthorization()
                    self.locationManager?.startUpdatingLocation()
                    
                    if let loc = self.locationManager?.location {
                        self.sendLocationToJS(id: id, location: loc)
                    }
                }
            } else if message.name == "notificationRequestPermission", let dict = message.body as? [String: Any], let id = dict["id"] as? String {
                guard message.frameInfo.isMainFrame else { return }
                DispatchQueue.main.async {
                    if let webView = self.state.webView, let host = webView.url?.host {
                        let handleResult: (PermissionState) -> Void = { newState in
                            SitePermissionStore.shared.setMediaPermission(for: host, type: "notifications", state: newState)
                            let resultStr = newState == .allow ? "granted" : (newState == .deny ? "denied" : "default")
                            webView.evaluateJavaScript("if (window['__balanceNotificationCallback_\(id)']) { window['__balanceNotificationCallback_\(id)']('\(resultStr)'); }", completionHandler: nil)
                        }
                        
                        let currentState = SitePermissionStore.shared.mediaPermission(for: host, type: "notifications")
                        if currentState == .ask {
                            let alert = NSAlert()
                            alert.messageText = "Allow \"\(host)\" to show notifications?"
                            alert.addButton(withTitle: "Allow")
                            alert.addButton(withTitle: "Deny")
                            let result = alert.runModal()
                            handleResult(result == .alertFirstButtonReturn ? .allow : .deny)
                        } else {
                            handleResult(currentState)
                        }
                    }
                }
            } else if message.name == "notificationShow", let dict = message.body as? [String: Any], let title = dict["title"] as? String {
                guard message.frameInfo.isMainFrame else { return }
                DispatchQueue.main.async {
                    if let webView = self.state.webView, let host = webView.url?.host {
                        let currentState = SitePermissionStore.shared.mediaPermission(for: host, type: "notifications")
                        if currentState == .allow {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                                if granted {
                                    let content = UNMutableNotificationContent()
                                    content.title = title
                                    if let body = dict["body"] as? String {
                                        content.body = body
                                    }
                                    if let urlStr = webView.url?.absoluteString {
                                        content.userInfo = ["url": urlStr]
                                    }
                                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                                    UNUserNotificationCenter.current().add(request)
                                }
                            }
                        }
                    }
                }
            }
        }





        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
            state.serverTrust = webView.serverTrust
            state.failedToLoad = false
            state.lastHighlightedQuery = ""
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("didFailProvisionalNavigation:", error)
            state.isLoading = false
            state.failedToLoad = showErrorPageIfNeeded(webView, error: error as NSError)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("didFail:", error)
            state.isLoading = false
            state.failedToLoad = showErrorPageIfNeeded(webView, error: error as NSError)
        }

        /// Classifies the failure and, if it's a real navigation error (not a cancellation),
        /// renders our own error page in place of WebKit's built-in one.
        private func showErrorPageIfNeeded(_ webView: WKWebView, error: NSError) -> Bool {
            guard let kind = ErrorPageBuilder.classify(error) else { return false }

            let failedURL = (error.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
                ?? webView.url
                ?? state.url
            lastFailedURL = failedURL

            let html = ErrorPageBuilder.html(for: kind, url: failedURL)


            let responseURL = failedURL ?? URL(string: "about:blank")!
            webView.loadSimulatedRequest(URLRequest(url: responseURL), responseHTML: html)
            return true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.url = webView.url
            state.serverTrust = webView.serverTrust
            syncNotificationPermission(in: webView)
            if state.customTitle == nil {
                state.title = webView.title ?? "Page"
            }
            if let x = state.restoredScrollX, let y = state.restoredScrollY {
                webView.evaluateJavaScript("window.scrollTo(\(x), \(y));", completionHandler: nil)
                state.restoredScrollX = nil
                state.restoredScrollY = nil
            }
            
            let host = webView.url?.host ?? "default"
            let p = profile.isEmpty ? "default" : profile
            
            let siteZoom = SitePermissionStore.shared.zoomLevel(for: host)
            let targetZoom = CGFloat(siteZoom) / 100.0
            if webView.pageZoom != targetZoom {
                webView.pageZoom = targetZoom
            }
            if state.zoomLevel != targetZoom {
                state.zoomLevel = targetZoom
            }
            let settingsKey = "boost_\(p)_\(host)"
            
            let hexColor = Config.sharedDefaults?.string(forKey: "\(settingsKey)_color")
            let fontName = Config.sharedDefaults?.string(forKey: "\(settingsKey)_font")
            let customCSS = Config.sharedDefaults?.string(forKey: "\(settingsKey)_css")
            
            if hexColor != nil || fontName != nil || customCSS != nil {
                var css = ""
                if let hexColor = hexColor {
                    css += "body { background-color: \(hexColor) !important; }\n"
                }
                if let fontName = fontName {
                    css += "* { font-family: \"\(fontName)\", -apple-system, sans-serif !important; }\n"
                }
                if let customCSS = customCSS {
                    css += customCSS + "\n"
                }
                
                guard let cssEncodedData = try? JSONEncoder().encode(css),
                      let jsCSSString = String(data: cssEncodedData, encoding: .utf8) else { return }
                
                let jsCode = """
                (function() {
                    var styleId = 'app-boost-style-override';
                    var styleElement = document.getElementById(styleId);
                    
                    if (!styleElement) {
                        styleElement = document.createElement('style');
                        styleElement.id = styleId;
                        document.head.appendChild(styleElement);
                    }
                    
                    styleElement.textContent = \(jsCSSString);
                })();
                """
                webView.evaluateJavaScript(jsCode, completionHandler: nil)
            }
        }


        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            state.url = webView.url
            state.serverTrust = webView.serverTrust
            syncNotificationPermission(in: webView)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     preferences: WKWebpagePreferences,
                     decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            
            if let url = navigationAction.request.url {
                print("decidePolicyFor:", url.absoluteString)

                if url.scheme == ErrorPageBuilder.retryScheme {
                    decisionHandler(.cancel, preferences)
                    if let retryURL = lastFailedURL {
                        webView.load(URLRequest(url: retryURL))
                    }
                    return
                }
                
                if let scheme = url.scheme?.lowercased(),
                   !["http", "https", "file", "about", "data", "blob", "webkit-extension", "chrome-extension"].contains(scheme) {

                    if let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) {
                        let appName = appURL.deletingPathExtension().lastPathComponent

                        print("Handler app:", appName)
                        print("Path:", appURL.path)

                        let alert = NSAlert()
                        alert.messageText = "Open URL in \(appName)?"
                        alert.addButton(withTitle: "Open")
                        alert.addButton(withTitle: "Cancel")

                        if alert.runModal() == .alertSecondButtonReturn {
                            decisionHandler(.cancel, preferences)
                            return
                        }

                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel, preferences)
                        return
                    }
                }
            }
            
            if let url = navigationAction.request.url {
                let httpsOnly = Config.sharedDefaults?.bool(forKey: "httpsOnly") ?? false
                if httpsOnly && url.scheme == "http" {
                    let host = url.host ?? ""
                    if host != "localhost" && host != "127.0.0.1" {
                        if let httpsUrl = URL(string: url.absoluteString.replacingOccurrences(of: "http://", with: "https://")) {
                            decisionHandler(.cancel, preferences)
                            webView.load(URLRequest(url: httpsUrl))
                            return
                        }
                    }
                }
            }
            
            let isExtensionScheme = navigationAction.request.url?.scheme?.hasSuffix("extension") == true
            
            if !isExtensionScheme {
                if let host = navigationAction.request.url?.host {
                    let jsSetting = SitePermissionStore.shared.setting(for: host, type: "javascript", defaultState: .allow)
                    preferences.allowsContentJavaScript = (jsSetting == .allow)
                }
                
                if navigationAction.shouldPerformDownload {
                    decisionHandler(.download, preferences)
                    return
                }
            }
            decisionHandler(.allow, preferences)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
                     
            if let scheme = navigationResponse.response.url?.scheme, scheme.hasSuffix("extension") {
                decisionHandler(.allow)
                return
            }

            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     navigationAction: WKNavigationAction,
                     didBecome download: WKDownload) {

            downloads.insert(download)
            DockProgressManager.shared.add(download: download)
            download.delegate = self
        }

        func webView(_ webView: WKWebView,
                     navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {

            downloads.insert(download)
            DockProgressManager.shared.add(download: download)
            download.delegate = self
        }
        
        var downloadTitles: [WKDownload: String] = [:]
        var downloadFrom: [WKDownload: String] = [:]
        var downloadTo: [WKDownload: String] = [:]
        var downloadTemporaryURLs: [WKDownload: URL] = [:]

        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {

            let filename = DownloadFilenameResolver.filename(
                linkFilename: downloadTitles[download],
                suggestedFilename: suggestedFilename,
                response: response
            )
            
            downloadTitles[download] = filename
            downloadFrom[download] = response.url?.absoluteString

            let panel = NSSavePanel()
            panel.nameFieldStringValue = filename

            panel.begin { [weak self] result in
                if result == .OK, let url = panel.url {
                    self?.downloadTo[download] = url.path

                    // WKDownload writes directly to its destination. Using the user's
                    // final path here exposes a partial ZIP/DMG to Finder, where it can
                    // be opened and reported as corrupt before the download finishes.
                    let temporaryName = UUID().uuidString + "." + url.pathExtension
                    let temporaryURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(temporaryName)
                    self?.downloadTemporaryURLs[download] = temporaryURL
                    completionHandler(temporaryURL)
                } else {
                    // Clean up tracking dictionaries for cancelled downloads to prevent leaks.
                    self?.downloadTitles.removeValue(forKey: download)
                    self?.downloadFrom.removeValue(forKey: download)
                    completionHandler(nil)
                }
            }
        }

                func downloadDidFinish(_ download: WKDownload) {
                    print("Download completed successfully!")
                    
                    let title = downloadTitles[download] ?? "Unknown File"
                    let url = downloadFrom[download] ?? "Unknown Location"
                    let to = downloadTo[download] ?? "Unknown path"

                    guard let temporaryURL = downloadTemporaryURLs[download],
                          let destinationURL = downloadTo[download].map(URL.init(fileURLWithPath:)) else {
                        finishTracking(download)
                        return
                    }

                    do {
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            _ = try FileManager.default.replaceItemAt(
                                destinationURL,
                                withItemAt: temporaryURL
                            )
                        } else {
                            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
                        }
                    } catch {
                        print("Failed to finalize download: \(error.localizedDescription)")
                        try? FileManager.default.removeItem(at: temporaryURL)
                        finishTracking(download)
                        return
                    }
                    
                    if !isPrivate {
                        downloadStore.add(Download(
                            title: title,
                            from:url,
                            to:to,
                            time:Date()
                        ))
                    }
                    finishTracking(download)
                }

                func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
                    print("Download failed with error: \(error.localizedDescription)")
                    if let temporaryURL = downloadTemporaryURLs[download] {
                        try? FileManager.default.removeItem(at: temporaryURL)
                    }
                    finishTracking(download)
                }

                private func finishTracking(_ download: WKDownload) {
                    downloads.remove(download)
                    DockProgressManager.shared.remove(download: download)
                    downloadTitles.removeValue(forKey: download)
                    downloadFrom.removeValue(forKey: download)
                    downloadTo.removeValue(forKey: download)
                    downloadTemporaryURLs.removeValue(forKey: download)
                }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            let isLinkActivated = navigationAction.navigationType == .linkActivated
            
            if !isLinkActivated {
                if let host = webView.url?.host {
                    let popupSetting = SitePermissionStore.shared.setting(for: host, type: "popups", defaultState: .block)
                    if popupSetting == .block {
                        if let url = navigationAction.request.url {
                            print("Blocked popup to \(url)")
                        }
                        return nil
                    }
                }
            }
            
            let newWebView = BrowserWKWebView(frame: .zero, configuration: configuration)
            let newState = BrowserState(initialURL: navigationAction.request.url)
            newState.preloadedWebView = newWebView
            
            DispatchQueue.main.async {
                createNewTab(with: navigationAction.request.url, inBackground: false, browserState: newState)
            }
            return newWebView
        }

        func webViewDidClose(_ webView: WKWebView) {
            DispatchQueue.main.async {
                WindowManager.shared.closeTab(self.state.tabID)
            }
        }

        @available(macOS 12.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let host = origin.host
            
            var cameraState: PermissionState = .allow
            var micState: PermissionState = .allow
            
            if type == .camera || type == .cameraAndMicrophone {
                cameraState = SitePermissionStore.shared.mediaPermission(for: host, type: "camera")
            }
            if type == .microphone || type == .cameraAndMicrophone {
                micState = SitePermissionStore.shared.mediaPermission(for: host, type: "microphone")
            }
            
            if cameraState == .deny || micState == .deny {
                decisionHandler(.deny)
                return
            }
            
            if (type == .camera && cameraState == .allow) ||
               (type == .microphone && micState == .allow) ||
               (type == .cameraAndMicrophone && cameraState == .allow && micState == .allow) {
                decisionHandler(.grant)
                return
            }
            
            let alert = NSAlert()
            var messageText = "The website \"\(host)\" would like to access your "
            if type == .camera {
                messageText += "camera."
            } else if type == .microphone {
                messageText += "microphone."
            } else {
                messageText += "camera and microphone."
            }
            alert.messageText = messageText
            alert.informativeText = "You can change this later in the site settings (padlock icon)."
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Deny")
            
            if let window = webView.window {
                alert.beginSheetModal(for: window) { response in
                    if response == .alertFirstButtonReturn {
                        if type == .camera || type == .cameraAndMicrophone {
                            SitePermissionStore.shared.setMediaPermission(for: host, type: "camera", state: .allow)
                        }
                        if type == .microphone || type == .cameraAndMicrophone {
                            SitePermissionStore.shared.setMediaPermission(for: host, type: "microphone", state: .allow)
                        }
                        decisionHandler(.grant)
                    } else {
                        if type == .camera || type == .cameraAndMicrophone {
                            SitePermissionStore.shared.setMediaPermission(for: host, type: "camera", state: .deny)
                        }
                        if type == .microphone || type == .cameraAndMicrophone {
                            SitePermissionStore.shared.setMediaPermission(for: host, type: "microphone", state: .deny)
                        }
                        decisionHandler(.deny)
                    }
                }
            } else {
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if type == .camera || type == .cameraAndMicrophone {
                        SitePermissionStore.shared.setMediaPermission(for: host, type: "camera", state: .allow)
                    }
                    if type == .microphone || type == .cameraAndMicrophone {
                        SitePermissionStore.shared.setMediaPermission(for: host, type: "microphone", state: .allow)
                    }
                    decisionHandler(.grant)
                } else {
                    if type == .camera || type == .cameraAndMicrophone {
                        SitePermissionStore.shared.setMediaPermission(for: host, type: "camera", state: .deny)
                    }
                    if type == .microphone || type == .cameraAndMicrophone {
                        SitePermissionStore.shared.setMediaPermission(for: host, type: "microphone", state: .deny)
                    }
                    decisionHandler(.deny)
                }
            }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {

            let alert = NSAlert()
            alert.messageText = message
            alert.runModal()
            completionHandler()
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {

            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            completionHandler(alert.runModal() == .alertFirstButtonReturn)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {

            if prompt == "BALANCE_INTERNAL_LOCATION_CHECK" {
                if let host = webView.url?.host {
                    let state = SitePermissionStore.shared.mediaPermission(for: host, type: "location")
                    
                    let handleAllow = {
                        if self.locationManager == nil {
                            self.locationManager = CLLocationManager()
                            self.locationManager?.delegate = self
                        }
                        self.locationManager?.requestWhenInUseAuthorization()
                        // On macOS, sometimes the prompt doesn't appear until you actually request the location.
                        self.locationManager?.startUpdatingLocation()
                    }
                    
                    if state == .ask {
                        let alert = NSAlert()
                        alert.messageText = "Allow \"\(host)\" to use your location?"
                        alert.addButton(withTitle: "Allow")
                        alert.addButton(withTitle: "Deny")
                        let result = alert.runModal()
                        let newState: PermissionState = (result == .alertFirstButtonReturn) ? .allow : .deny
                        SitePermissionStore.shared.setMediaPermission(for: host, type: "location", state: newState)
                        
                        if newState == .allow {
                            handleAllow()
                        }
                        completionHandler(newState.rawValue)
                    } else {
                        if state == .allow {
                            handleAllow()
                        }
                        completionHandler(state.rawValue)
                    }
                } else {
                    completionHandler("Ask")
                }
                return
            }

            let alert = NSAlert()
            alert.messageText = prompt

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.stringValue = defaultText ?? ""
            alert.accessoryView = input

            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let result = alert.runModal()
            completionHandler(result == .alertFirstButtonReturn ? input.stringValue : nil)
        }
        
        func webView(_ webView: WKWebView,
                     runOpenPanelWith parameters: WKOpenPanelParameters,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping ([URL]?) -> Void) {
            
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = parameters.allowsDirectories
            openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
            
            openPanel.begin { result in
                if result == .OK {
                    completionHandler(openPanel.urls)
                } else {
                    completionHandler(nil)
                }
            }
        }

    }
}

// MARK: - Manager

final class WebExtensionManager: NSObject, ObservableObject, WKWebExtensionControllerDelegate {
    static let shared = WebExtensionManager()
    
    private var controllers: [String: WKWebExtensionController] = [:]
    
    @Published var contexts: [WKWebExtensionContext] = []
    private var contextURLs: [WKWebExtensionContext: URL] = [:]
    
    @Published var popupWebView: WKWebView?
    @Published var popupContext: WKWebExtensionContext?
    @Published var showPopup: Bool = false
    
    var activeTab: BrowserState?
    var allTabs: Set<BrowserState> = []
    let window = BrowserWindow()
    
    private var openedControllers: Set<ObjectIdentifier> = []
    private var hasLoaded = false
    
    private override init() {
        super.init()
    }

    func openWindowIfNeeded(for controller: WKWebExtensionController) {
        let controllerID = ObjectIdentifier(controller)
        guard openedControllers.insert(controllerID).inserted else { return }
        controller.didOpenWindow(window)
    }
    
    // MARK: - WKWebExtensionControllerDelegate
    
    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        [WebExtensionManager.shared.window]
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        WebExtensionManager.shared.window
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            WebExtensionManager.shared.popupWebView = action.popupWebView
            WebExtensionManager.shared.popupContext = extensionContext
            WebExtensionManager.shared.showPopup = true
            completionHandler(nil)
        }
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void) {
        let granted = confirmPermissionRequest(
            permissions.map { String(describing: $0) },
            for: extensionContext
        ) ? permissions : []
        completionHandler(granted, nil)
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void) {
        let granted = confirmPermissionRequest(
            matchPatterns.map { String(describing: $0) },
            for: extensionContext
        ) ? matchPatterns : []
        completionHandler(granted, nil)
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<URL>, Date?) -> Void) {
        let granted = confirmPermissionRequest(
            urls.map(\.absoluteString),
            for: extensionContext
        ) ? urls : []
        completionHandler(granted, nil)
    }

    private func confirmPermissionRequest(
        _ requestedItems: [String],
        for extensionContext: WKWebExtensionContext
    ) -> Bool {
        guard !requestedItems.isEmpty else { return true }

        let extensionName = extensionContext.webExtension.manifest["name"] as? String
            ?? "This extension"
        let visibleItems = requestedItems.sorted().prefix(8)
        var details = visibleItems.map { "• \($0)" }.joined(separator: "\n")
        if requestedItems.count > visibleItems.count {
            details += "\n• …and \(requestedItems.count - visibleItems.count) more"
        }

        let alert = NSAlert()
        alert.messageText = "Allow \"\(extensionName)\" additional access?"
        alert.informativeText = details
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Deny")
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
        if let optionsURL = extensionContext.optionsPageURL {
            DispatchQueue.main.async {
                createNewTab(with: optionsURL)
            }
        }
        completionHandler(nil)
    }
    
    func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration, for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, Error?) -> Void) {
        let newState = BrowserState(initialURL: configuration.url)
        if let url = configuration.url {
            DispatchQueue.main.async {
                createNewTab(with: url, browserState: newState)
            }
        }
        completionHandler(newState, nil)
    }
    
    func controller(for profile: String) -> WKWebExtensionController {
        let key = profile.isEmpty ? "default" : profile
        if let existing = controllers[key] { return existing }
        let extConfig = WKWebExtensionController.Configuration.default()
        if !profile.isEmpty, let profileUUID = UUID(uuidString: profile) {
            extConfig.defaultWebsiteDataStore = WKWebsiteDataStore(forIdentifier: profileUUID)
        } else {
            extConfig.defaultWebsiteDataStore = .default()
        }
        let newController = WKWebExtensionController(configuration: extConfig)
        controllers[key] = newController
        
        // Load existing contexts into the new controller
        for context in contexts {
            do {
                try newController.load(context)
            } catch {
                print("Failed to load context into new controller '\(key)': \(error)")
            }
        }
        
        return newController
    }
    
    /// Loads all extensions from disk. Only runs once; subsequent calls are no-ops.
    func loadAllFromDisk() {
        guard !hasLoaded else { return }
        hasLoaded = true
        // Initialize default controller
        _ = controller(for: "default")
        ExtensionStorage.loadInstalledExtensions()
    }
    
    func loadExtension(from url: URL) {
        Task { @MainActor in
            do {
                let ext = try await WKWebExtension(resourceBaseURL: url)
                let context = WKWebExtensionContext(for: ext)
                
                let uuidKey = "ext_uuid_\(url.lastPathComponent)"
                if let saved = Config.sharedDefaults?.string(forKey: uuidKey) {
                    context.uniqueIdentifier = saved
                } else {
                    Config.sharedDefaults?.set(context.uniqueIdentifier, forKey: uuidKey)
                }
                
                contextURLs[context] = url
                
                // Grant all requested permissions from manifest
                for permission in ext.requestedPermissions {
                    context.setPermissionStatus(.grantedExplicitly, for: permission, expirationDate: nil)
                }
                
                // Grant all requested match patterns from manifest
                for pattern in ext.requestedPermissionMatchPatterns {
                    context.setPermissionStatus(.grantedExplicitly, for: pattern, expirationDate: nil)
                }
                
                for (key, controller) in controllers {
                    do {
                        try controller.load(context)
                    } catch {
                        print("Failed to load extension into controller '\(key)': \(error)")
                    }
                }
                contexts.append(context)
            } catch {
                print("Failed to load extension from \(url):", error)
            }
        }
    }
    
    func unloadExtension(_ context: WKWebExtensionContext) {
        for (_, controller) in controllers {
            try? controller.unload(context)
        }
        contexts.removeAll { $0 === context }
        contextURLs.removeValue(forKey: context)
    }
    
    func unloadAll() {
        for context in contexts {
            for (_, controller) in controllers {
                try? controller.unload(context)
            }
        }
        contexts.removeAll()
        contextURLs.removeAll()
    }
    
    /// Removes an extension's files from disk and unloads it.
    func removeExtensionFromDisk(_ context: WKWebExtensionContext) {
        let fileURL = contextURLs[context]
        unloadExtension(context)
        
        guard let fileURL = fileURL else {
            print("No file URL found for extension context")
            return
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to remove extension files at \(fileURL):", error)
        }
    }
}

// MARK: - Storage

enum ExtensionStorage {
    
    static func extensionsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let dir = base.appendingPathComponent("Extensions", isDirectory: true) // ext dir
        
        print("ext dir, \(dir)")
        
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        return dir
    }
    
    static func removeQuarantine(from url: URL) {
        removexattr(url.path, "com.apple.quarantine", 0)
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                removexattr(fileURL.path, "com.apple.quarantine", 0)
            }
        }
    }
    
    static func loadInstalledExtensions() {
        guard let dir = try? extensionsDirectory() else { return }
        
        removeQuarantine(from: dir)
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for folder in contents {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir),
                   isDir.boolValue {
                    let dirURL = URL(fileURLWithPath: folder.path, isDirectory: true)
                    WebExtensionManager.shared.loadExtension(from: dirURL)
                }
            }
        }
    }
}

// MARK: - CRX Installer

enum CRXInstaller {
    
    // Download CRX
    static func download(from url: URL) async throws -> URL {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"]
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw NSError(domain: "CRXDownload", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to download CRX. URL: \(url.absoluteString). HTTP Status: \(httpResponse.statusCode). Response: \(body)"
            ])
        }
        
        let safeURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".crx")
        if FileManager.default.fileExists(atPath: safeURL.path) {
            try? FileManager.default.removeItem(at: safeURL)
        }
        try data.write(to: safeURL)
        return safeURL
    }
    
    // Install CRX (download already done)
    static func install(from crxURL: URL, originalURL: URL? = nil) async throws {
        let extensionsDir = try ExtensionStorage.extensionsDirectory()
        
        var extID = UUID().uuidString
        if let original = originalURL?.absoluteString, let range = original.range(of: "x=id%3D") {
            let afterId = original[range.upperBound...]
            if let endRange = afterId.range(of: "%26") {
                let extracted = String(afterId[..<endRange.lowerBound])
                if extracted.range(of: #"^[a-p]{32}$"#, options: .regularExpression) != nil {
                    extID = extracted
                }
            }
        }
        
        let dest = extensionsDir.appendingPathComponent(extID)
        
        // Remove existing directory if re-installing
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        
        do {
            try extractCRX(at: crxURL, to: dest)
            
            let manifestURL = findManifest(in: dest)
            
            guard let manifestURL else {
                throw NSError(domain: "Extension", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "manifest.json not found — the download may not be a valid CRX file"
                ])
            }
            
            let root = manifestURL.deletingLastPathComponent()
            let dirURL = URL(fileURLWithPath: root.path, isDirectory: true)
            WebExtensionManager.shared.loadExtension(from: dirURL)
        } catch {
            // Clean up the empty/invalid directory so it doesn't appear as an empty extension
            try? FileManager.default.removeItem(at: dest)
            throw error
        }
    }
    
    // Combined helper
    static func install(fromRemote url: URL) {
        Task {
            do {
                let crx = try await download(from: url)
                defer { try? FileManager.default.removeItem(at: crx) }
                try await install(from: crx, originalURL: url)
                
                // Update UI state on main thread
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("ExtensionsUpdated"), object: nil)
                }
                print("Extension installed")
            } catch {
                print("Install failed:", error)
            }
        }
    }
}

// MARK: - CRX Extraction

func extractCRX(at url: URL, to destination: URL) throws {
    let data = try Data(contentsOf: url)
    
    let isZip = String(data: data.prefix(2), encoding: .ascii) == "PK"
    
    guard isZip || String(data: data.prefix(4), encoding: .ascii) == "Cr24" else {
        let prefixStr = String(data: data.prefix(200), encoding: .utf8) ?? "binary data"
        print("CRX extraction failed. Data size: \(data.count) bytes. First 200 bytes: \(prefixStr)")
        throw NSError(domain: "CRX", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Invalid CRX file"
        ])
    }
    
    let zipData: Data
    
    if isZip {
        zipData = data
    } else {
        func readUInt32(at offset: Int) -> UInt32? {
            guard offset >= 0, data.count >= offset + MemoryLayout<UInt32>.size else {
                return nil
            }
            return UInt32(data[offset])
                | (UInt32(data[offset + 1]) << 8)
                | (UInt32(data[offset + 2]) << 16)
                | (UInt32(data[offset + 3]) << 24)
        }

        guard let version = readUInt32(at: 4) else {
            throw NSError(domain: "CRX", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Truncated CRX header"
            ])
        }
        let zipStart: Int
        
        if version == 2 {
            guard let pubKeyLen = readUInt32(at: 8),
                  let sigLen = readUInt32(at: 12) else {
                throw NSError(domain: "CRX", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Truncated CRX2 header"
                ])
            }
            zipStart = 16 + Int(pubKeyLen) + Int(sigLen)
        } else if version == 3 {
            guard let headerLen = readUInt32(at: 8) else {
                throw NSError(domain: "CRX", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Truncated CRX3 header"
                ])
            }
            zipStart = 12 + Int(headerLen)
        } else {
            throw NSError(domain: "CRX", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported CRX version"
            ])
        }

        guard zipStart >= 0,
              zipStart <= data.count - 2,
              data[zipStart] == 0x50,
              data[zipStart + 1] == 0x4B else {
            throw NSError(domain: "CRX", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Invalid or truncated CRX payload"
            ])
        }
        zipData = data.subdata(in: zipStart..<data.count)
    }
    

    
    let zipURL = destination.appendingPathComponent("temp.zip")
    try zipData.write(to: zipURL)
    
    try FileManager.default.unzipItem(at: zipURL, to: destination)
    
    // Remove quarantine attribute so WebKit's network process can read the files
    ExtensionStorage.removeQuarantine(from: destination)
    
    try? FileManager.default.removeItem(at: zipURL)
}

// MARK: - Helpers

func findManifest(in directory: URL) -> URL? {
    let fm = FileManager.default
    
    let rootManifest = directory.appendingPathComponent("manifest.json")
    if fm.fileExists(atPath: rootManifest.path) {
        return rootManifest
    }
    
    if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
        for item in contents {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let nestedManifest = item.appendingPathComponent("manifest.json")
                if fm.fileExists(atPath: nestedManifest.path) {
                    return nestedManifest
                }
            }
        }
    }
    
    return nil
}
