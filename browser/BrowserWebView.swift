import SwiftUI
import WebKit
import AppKit
internal import Combine
import ZIPFoundation
import CoreLocation

final class BrowserState: NSObject, ObservableObject, WKWebExtensionTab {
    @Published var url: URL?
    @Published var title: String = ""
    @Published var customTitle: String? = nil
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var favicon: NSImage?
    weak var webView: WKWebView?
    @Published var isFindBarVisible: Bool = false
    @Published var findQuery: String = ""
    @Published var findMatchCount: Int = 0
    @Published var isAudioMuted: Bool = false
    
    @Published var scrollX: Int = 0
    @Published var scrollY: Int = 0
    var restoredScrollX: Int?
    var restoredScrollY: Int?

    
    // MARK: - WKWebExtensionTab
    
    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        WebExtensionManager.shared.window
    }
    
    func webView(for context: WKWebExtensionContext) -> WKWebView? {
        self.webView
    }
    
    func title(for context: WKWebExtensionContext) -> String? {
        self.title
    }
    
    func url(for context: WKWebExtensionContext) -> URL? {
        self.url
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
        webView?.frame.size ?? .zero
    }
    func zoomFactor(for context: WKWebExtensionContext) -> Double { 1.0 }
    
    func toggleMute() {
        isAudioMuted.toggle()
        let js = "document.querySelectorAll('video, audio').forEach(function(element) { element.muted = \(isAudioMuted ? "true" : "false"); });"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    @Published var zoomLevel: CGFloat = 1.0
    
    
func applyZoom() {    
    let js = "document.body.style.zoom = '\(zoomLevel)';"
    
    webView?.evaluateJavaScript(js, completionHandler: { result, error in
        if let error = error {
            print("Failed to apply zoom script: \(error.localizedDescription)")
        }
    })
}

    
    public func zoomIn() {
        zoomLevel = min(2.0, zoomLevel + 0.1)
        applyZoom()
    }

    public func zoomOut() {
        zoomLevel = max(0.5, zoomLevel - 0.1)
        applyZoom()
    }

    public func resetZoom() {
        zoomLevel = 1.0
        applyZoom()
    }
}

// MARK: - Browser Window

final class BrowserWindow: NSObject, WKWebExtensionWindow {
    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        Array(WebExtensionManager.shared.allTabs)
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
    }
    
    func find(_ query: String, forward: Bool = true) {
        guard !query.isEmpty else {
            clearFind()
            return
        }
        highlightAll(query)  // add this
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.caseSensitive = false
        config.wraps = true
        webView?.find(query, configuration: config) { _ in }
    }


    func clearFind() {
        clearHighlights()  // add this
        webView?.find("", configuration: WKFindConfiguration()) { _ in }
    }
    
        func highlightAll(_ query: String) {
            guard !query.isEmpty else {
                clearHighlights()
                return
            }

            let js = """
            (function() {
                // Clear previous highlights first
                document.querySelectorAll('mark.__find_highlight').forEach(el => {
                    el.replaceWith(...el.childNodes);
                });
                document.normalize();

                const query = JSON.stringify(\(query));
                if (!query) return 0;

                const walker = document.createTreeWalker(
                    document.body,
                    NodeFilter.SHOW_TEXT,
                    null
                );

                const ranges = [];
                let node;
                while ((node = walker.nextNode())) {
                    const text = node.nodeValue;
                    const lower = text.toLowerCase();
                    const queryLower = query.toLowerCase();
                    let idx = 0;
                    while ((idx = lower.indexOf(queryLower, idx)) !== -1) {
                        const range = document.createRange();
                        range.setStart(node, idx);
                        range.setEnd(node, idx + query.length);
                        ranges.push(range);
                        idx += query.length;
                    }
                }

                ranges.forEach(range => {
                    const mark = document.createElement('mark');
                    mark.className = '__find_highlight';
                    mark.style.cssText = 'background: #FFFF00; color: black;';
                    range.surroundContents(mark);
                });

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
    
    let downloadStore = DownloadStore()
    var state: BrowserState?
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if let state = state, result {
            let manager = WebExtensionManager.shared
            manager.activeTab = state
            if let extController = self.configuration.webExtensionController {
                extController.didActivateTab(state)
            }
        }
        return result
    }

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

struct BrowserWebView: NSViewRepresentable {
    let request: URLRequest
    @ObservedObject var state: BrowserState
    
    var priv: Bool = false
    var profile = ""
    var userAgent: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "fullScreenEnabled")
        if #available(macOS 12.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Media configurations useful for DRM / FairPlay streams
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        
        // Chrome Web Store integration
        config.userContentController.add(context.coordinator, name: "installExtension")
        
        let installedIDs = WebExtensionManager.shared.contexts.compactMap { $0.baseURL.lastPathComponent }
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
                                }, 2000);
                            });
                        }
                        
                        clearInterval(checkInterval);
                    }
                }
            }, 1000);
        })();
        """
        let script = WKUserScript(source: cwsScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
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
        let locScript = WKUserScript(source: locationScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(locScript)
        config.userContentController.add(context.coordinator, name: "balanceLocation")
        
        let dntEnabled = Config.sharedDefaults?.bool(forKey: "doNotTrack") ?? false
        if dntEnabled {
            let dntScript = WKUserScript(source: "Object.defineProperty(navigator, 'doNotTrack', { get: function() { return '1'; } });", injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(dntScript)
        }
        
        WebExtensionManager.shared.loadAllFromDisk()
        WebExtensionManager.shared.activeTab = state
        
        var profileContext = ""
        
        if priv {
            profileContext = "priv"
        }

        
        if !profile.isEmpty {
            profileContext = "profile"
        }
        
        switch profileContext {

        case "priv":
            config.websiteDataStore = .nonPersistent()

        case "profile":
            config.websiteDataStore = WKWebsiteDataStore(forIdentifier: UUID(uuidString: profile)!)
            
        default:
            config.websiteDataStore = .default()
        }
        
        let controller = WebExtensionManager.shared.controller(for: profileContext)
        config.webExtensionController = controller
        config.webExtensionController?.delegate = context.coordinator

        let webView = BrowserWKWebView(frame: .zero, configuration: config)
        if !userAgent.isEmpty {
            webView.customUserAgent = userAgent
        }
        
        let defaultZoom = (Config.sharedDefaults?.object(forKey: "defaultPageZoom") as? Int) ?? 100
        webView.pageZoom = CGFloat(defaultZoom) / 100.0
        webView.state = state
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        DispatchQueue.main.async {
            state.attach(webView)
        }
        
        let manager = WebExtensionManager.shared
        let extController = manager.controller(for: profileContext)
        if !manager.hasOpenedWindow {
            extController.didOpenWindow(manager.window)
            manager.hasOpenedWindow = true
        }
        manager.allTabs.insert(state)
        extController.didOpenTab(state)
        extController.didActivateTab(state)
        manager.activeTab = state

        webView.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "title", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "URL", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "canGoBack", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "canGoForward", options: .new, context: nil)
        
        webView.allowsBackForwardNavigationGestures = true
        
            let base = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let fileManager = FileManager.default
            let dir = base!.appendingPathComponent("Balance/contentblockers", isDirectory: true)
        
            let userContentController = webView.configuration.userContentController

            userContentController.removeAllContentRuleLists()

            do {
                let items = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)

                for item in items {
                    // Load JSON rules from file
                    let jsonStr = try String(contentsOf: item, encoding: .utf8)

                    let identifier = "dynamicRules-\(UUID().uuidString)"

                    guard let data = jsonStr.data(using: .utf8),
                          (try? JSONSerialization.jsonObject(with: data)) != nil else {
                        print("addToContentBlocker — invalid JSON rules at: \(item.lastPathComponent)")
                        continue
                    }

                    WKContentRuleListStore.default().compileContentRuleList(
                        forIdentifier: identifier,
                        encodedContentRuleList: jsonStr
                    ) { ruleList, error in
                        if let error {
                            print("Failed to compile content blocker rules: \(error.localizedDescription)")
                            return
                        }

                        guard let ruleList else {
                            print("Failed to compile content blocker rules: no rule list returned")
                            return
                        }

                        userContentController.add(ruleList)
                    }
                }
            } catch {
                print("Error reading directory: \(error.localizedDescription)")
            }
        
        context.coordinator.lastLoadedRequestURL = request.url
        if let url = request.url, url.isFileURL, url.absoluteString.hasPrefix("file://") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(request)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let defaultZoom = (Config.sharedDefaults?.object(forKey: "defaultPageZoom") as? Int) ?? 100
        let targetZoom = CGFloat(defaultZoom) / 100.0
        if nsView.pageZoom != targetZoom {
            nsView.pageZoom = targetZoom
        }
        if context.coordinator.lastLoadedRequestURL != request.url {
            context.coordinator.lastLoadedRequestURL = request.url
            if let url = request.url, url.isFileURL, url.absoluteString.hasPrefix("file://") {
                nsView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                nsView.load(request)
            }
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.removeObserver(coordinator, forKeyPath: "estimatedProgress")
        nsView.removeObserver(coordinator, forKeyPath: "title")
        nsView.removeObserver(coordinator, forKeyPath: "URL")
        nsView.removeObserver(coordinator, forKeyPath: "canGoBack")
        nsView.removeObserver(coordinator, forKeyPath: "canGoForward")
        let manager = WebExtensionManager.shared
        manager.allTabs.remove(coordinator.state)
        if let controller = nsView.configuration.webExtensionController {
            controller.didCloseTab(coordinator.state)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler, WKWebExtensionControllerDelegate, CLLocationManagerDelegate {
        
        let downloadStore = DownloadStore()
        var locationManager: CLLocationManager?

        let state: BrowserState
        var downloads: Set<WKDownload> = []
        var lastLoadedRequestURL: URL?

        init(state: BrowserState) {
            self.state = state
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
            // Auto-grant all requested permissions
            completionHandler(permissions, nil)
        }
        
        func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void) {
            // Auto-grant all requested match patterns
            completionHandler(matchPatterns, nil)
        }
        
        func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>, in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext, completionHandler: @escaping (Set<URL>, Date?) -> Void) {
            // Auto-grant access to all URLs
            completionHandler(urls, nil)
        }
        
        func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
            if let optionsURL = extensionContext.optionsPageURL {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openURLInNewTab,
                        object: nil,
                        userInfo: ["url": optionsURL]
                    )
                }
            }
            completionHandler(nil)
        }
        
        func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration, for extensionContext: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, Error?) -> Void) {
            if let url = configuration.url {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openURLInNewTab,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
            }
            completionHandler(WebExtensionManager.shared.activeTab, nil)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "installExtension", let extId = message.body as? String {
                let downloadURLString = "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=114.0.0.0&acceptformat=crx2,crx3&x=id%3D" + extId + "%26installsource%3Dondemand%26uc"
                if let url = URL(string: downloadURLString) {
                    CRXInstaller.install(fromRemote: url)
                }
            } else if message.name == "scrollObserver", let dict = message.body as? [String: Any] {
                if let x = dict["x"] as? NSNumber, let y = dict["y"] as? NSNumber {
                    DispatchQueue.main.async {
                        self.state.scrollX = x.intValue
                        self.state.scrollY = y.intValue
                    }
                }
            } else if message.name == "balanceLocation", let dict = message.body as? [String: Any] {
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
            }
        }

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey : Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard let webView = object as? WKWebView else { return }

            DispatchQueue.main.async {
                switch keyPath {
                case "estimatedProgress":
                    self.state.progress = webView.estimatedProgress
                    self.state.isLoading = webView.isLoading
                case "title":
                    if self.state.customTitle == nil {
                        self.state.title = webView.title ?? "Page"
                    }
                case "URL":
                    self.state.url = webView.url
                    if let extController = webView.configuration.webExtensionController {
                        extController.didChangeTabProperties([.URL], for: self.state)
                    }
                case "canGoBack":
                    self.state.canGoBack = webView.canGoBack
                case "canGoForward":
                    self.state.canGoForward = webView.canGoForward
                default:
                    break
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            state.isLoading = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("didFailProvisionalNavigation:", error)
            state.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("didFail:", error)
            state.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.url = webView.url
            if state.customTitle == nil {
                state.title = webView.title ?? "Page"
            }
            if let x = state.restoredScrollX, let y = state.restoredScrollY {
                webView.evaluateJavaScript("window.scrollTo(\(x), \(y));", completionHandler: nil)
                state.restoredScrollX = nil
                state.restoredScrollY = nil
            }
        }


        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            state.url = webView.url
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     preferences: WKWebpagePreferences,
                     decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            
            if let url = navigationAction.request.url {
                print("decidePolicyFor:", url.absoluteString)
            }
            
            if let url = navigationAction.request.url {
                let httpsOnly = Config.sharedDefaults?.bool(forKey: "httpsOnly") ?? false
                if httpsOnly && url.scheme == "http" {
                    if let httpsUrl = URL(string: url.absoluteString.replacingOccurrences(of: "http://", with: "https://")) {
                        decisionHandler(.cancel, preferences)
                        webView.load(URLRequest(url: httpsUrl))
                        return
                    }
                }
            }
            
            if let host = navigationAction.request.url?.host {
                let jsSetting = SitePermissionStore.shared.setting(for: host, type: "javascript", defaultState: .allow)
                preferences.allowsContentJavaScript = (jsSetting == .allow)
            }

            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
                return
            }
            decisionHandler(.allow, preferences)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

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
            download.delegate = self
        }

        func webView(_ webView: WKWebView,
                     navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {

            downloads.insert(download)
            download.delegate = self
        }
        
        var downloadTitles: [WKDownload: String] = [:]
        var downloadFrom: [WKDownload: String] = [:]
        var downloadTo: [WKDownload: String] = [:]

        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {

            var filename: String = suggestedFilename
            if let preTitle = downloadTitles[download], !preTitle.isEmpty {
                filename = preTitle
            } else if !suggestedFilename.isEmpty && suggestedFilename != "download" {
                filename = suggestedFilename
            } else if let lastComponent = response.url?.lastPathComponent, !lastComponent.isEmpty {
                filename = lastComponent
            } else {
                filename = "download"
            }
            
            downloadTitles[download] = filename
            downloadFrom[download] = response.url?.absoluteString

            let panel = NSSavePanel()
            panel.nameFieldStringValue = filename

            panel.begin { [weak self] result in
                if result == .OK, let url = panel.url {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try? FileManager.default.removeItem(at: url)
                    }
                    self?.downloadTo[download] = url.path
                    completionHandler(url)
                } else {
                    completionHandler(nil)
                }
            }
        }

                func downloadDidFinish(_ download: WKDownload) {
                    print("Download completed successfully!")
                    
                    let title = downloadTitles[download] ?? "Unknown File"
                    let url = downloadFrom[download] ?? "Unknown Location"
                    let to = downloadTo[download] ?? "Unknown path"
                    
                    downloadStore.add(Download(
                        title: title,
                        from:url,
                        to:to,
                        time:Date()
                    ))
                    downloads.remove(download)
                }

                func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
                    print("Download failed with error: \(error.localizedDescription)")
                    downloads.remove(download)
                }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            if let url = navigationAction.request.url {
                let isLinkActivated = navigationAction.navigationType == .linkActivated
                
                if !isLinkActivated {
                    if let host = webView.url?.host {
                        let popupSetting = SitePermissionStore.shared.setting(for: host, type: "popups", defaultState: .block)
                        if popupSetting == .block {
                            print("Blocked popup to \(url)")
                            return nil
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    createNewTab(with: url, inBackground: true)
                }
            }
            return nil
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
            
            decisionHandler(.prompt)
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

final class WebExtensionManager: ObservableObject {
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
    
    var hasOpenedWindow = false
    private var hasLoaded = false
    
    private init() {}
    
    func controller(for profile: String) -> WKWebExtensionController {
        let key = profile.isEmpty ? "default" : profile
        if let existing = controllers[key] { return existing }
        let newController = WKWebExtensionController()
        controllers[key] = newController
        
        // Load existing contexts into the new controller
        for context in contexts {
            try? newController.load(context)
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
                contextURLs[context] = url
                
                // Grant all requested permissions from manifest
                for permission in ext.requestedPermissions {
                    context.setPermissionStatus(.grantedExplicitly, for: permission, expirationDate: nil)
                }
                
                // Grant all requested match patterns from manifest
                for pattern in ext.requestedPermissionMatchPatterns {
                    context.setPermissionStatus(.grantedExplicitly, for: pattern, expirationDate: nil)
                }
                
                // Grant access to all URLs so content scripts can inject as a fallback
                if let allURLs = try? WKWebExtension.MatchPattern(string: "<all_urls>") {
                    context.setPermissionStatus(.grantedExplicitly, for: allURLs, expirationDate: nil)
                }
                
                for (_, controller) in controllers {
                    try? controller.load(context)
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
        
        let dir = base.appendingPathComponent("Balance/extensions", isDirectory: true)
        
        print("ext dir, \(dir)")
        
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        return dir
    }
    
    static func loadInstalledExtensions() {
        do {
            let dir = try extensionsDirectory()
            let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            
            for folder in contents {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir),
                   isDir.boolValue {
                    
                    WebExtensionManager.shared.loadExtension(from: folder)
                }
            }
        } catch {
            print("Failed to load extensions:", error)
        }
    }
}

// MARK: - CRX Installer

enum CRXInstaller {
    
    // Download CRX
    static func download(from url: URL) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        return tempURL
    }
    
    // Install CRX (download already done)
    static func install(from crxURL: URL, originalURL: URL? = nil) async throws {
        let extensionsDir = try ExtensionStorage.extensionsDirectory()
        
        var extID = UUID().uuidString
        if let original = originalURL?.absoluteString, let range = original.range(of: "x=id%3D") {
            let afterId = original[range.upperBound...]
            if let endRange = afterId.range(of: "%26") {
                let extracted = String(afterId[..<endRange.lowerBound])
                if extracted.count == 32 {
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
        
        try extractCRX(at: crxURL, to: dest)
        
        let manifestURL = findManifest(in: dest)
        
        guard let manifestURL else {
            // Clean up the empty/invalid directory
            try? FileManager.default.removeItem(at: dest)
            throw NSError(domain: "Extension", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "manifest.json not found — the download may not be a valid CRX file"
            ])
        }
        
        let root = manifestURL.deletingLastPathComponent()
        
         WebExtensionManager.shared.loadExtension(from: root)
    }
    
    // Combined helper
    static func install(fromRemote url: URL) {
        Task {
            do {
                let crx = try await download(from: url)
                try await install(from: crx, originalURL: url)
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
    
    guard String(data: data.prefix(4), encoding: .ascii) == "Cr24" else {
        throw NSError(domain: "CRX", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Invalid CRX file"
        ])
    }
    
    let version = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
    
    let zipStart: Int
    
    if version == 2 {
        let pubKeyLen = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }
        let sigLen = data.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt32.self) }
        zipStart = 16 + Int(pubKeyLen) + Int(sigLen)
    } else if version == 3 {
        let headerLen = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }
        zipStart = 12 + Int(headerLen)
    } else {
        throw NSError(domain: "CRX", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Unsupported CRX version"
        ])
    }
    
    let zipData = data.subdata(in: zipStart..<data.count)
    
    let zipURL = destination.appendingPathComponent("temp.zip")
    try zipData.write(to: zipURL)
    
    try FileManager.default.unzipItem(at: zipURL, to: destination)
    
    try? FileManager.default.removeItem(at: zipURL)
}

// MARK: - Helpers

func findManifest(in directory: URL) -> URL? {
    let fm = FileManager.default
    
    if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "manifest.json" {
                return fileURL
            }
        }
    }
    
    return nil
}

