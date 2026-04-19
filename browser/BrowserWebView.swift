import SwiftUI
import WebKit
import AppKit
internal import Combine

final class BrowserState: ObservableObject {
    @Published var url: URL?
    @Published var title: String = ""
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var favicon: NSImage?
    weak var webView: WKWebView?
    @Published var isFindBarVisible: Bool = false
    @Published var findQuery: String = ""
    @Published var findMatchCount: Int = 0
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

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
            print("custom menu is finally firing!")
        
            menu.addItem(.separator())

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
          //          isLink = true
                }
                
                if id.contains("WKMenuItemIdentifierOpenImageInNewWindow") {
                    item.title = "Open Image in New Tab"
                }
            }

        menu.addItem(.separator())

            // 2. Add custom Download button if applicable
            if isDownloadable {
                let item = NSMenuItem(title: "Download \(downloadType == "WKMenuItemIdentifierDownloadImage" ? "Image" : "Linked File")", action: #selector(manualDownload(_:)), keyEquivalent: "", )
                item.target = self
                
                item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Download")
                
                // Store the click point instead of blocking the main thread with hitTestURL!
                let point = convert(event.locationInWindow, from: nil)
                item.representedObject = NSValue(point: point)
                
                menu.addItem(item)
            } else {
                print("Not a downloadable link or image")
            }
        }
    
    @objc func openInNewTab(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { print("no url"); return }
        DispatchQueue.main.async {
            createNewTab(with: url)
        }
    }
 
    @objc func manualDownload(_ sender: NSMenuItem) {
        guard let pointValue = sender.representedObject as? NSValue else { return }
        let point = pointValue.pointValue

        evaluateJavaScript("""
        (function() {
            let el = document.elementFromPoint(\(point.x), \(point.y));
            if (!el) return null;
            if (el.tagName === 'IMG') return el.src;
            let a = el.closest('a');
            return a ? a.href : null;
        })()
        """) { value, _ in
            guard let urlString = value as? String, let url = URL(string: urlString) else { return }
            let request = URLRequest(url: url)
            Task { @MainActor in
                let download = await self.startDownload(using: request)
                if let coordinator = self.navigationDelegate as? BrowserWebView.Coordinator {
                    coordinator.downloads.insert(download)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = BrowserWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        state.attach(webView)

        webView.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "title", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "URL", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "canGoBack", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "canGoForward", options: .new, context: nil)
        
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.removeObserver(coordinator, forKeyPath: "estimatedProgress")
        nsView.removeObserver(coordinator, forKeyPath: "title")
        nsView.removeObserver(coordinator, forKeyPath: "URL")
        nsView.removeObserver(coordinator, forKeyPath: "canGoBack")
        nsView.removeObserver(coordinator, forKeyPath: "canGoForward")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        
        let downloadStore = DownloadStore()

        let state: BrowserState
        var downloads: Set<WKDownload> = []

        init(state: BrowserState) {
            self.state = state
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
                    self.state.title = webView.title ?? ""
                case "URL":
                    self.state.url = webView.url
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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.isLoading = false
            state.url = webView.url
            state.title = webView.title ?? ""
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            state.url = webView.url
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
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

            let filename: String
            if !suggestedFilename.isEmpty && suggestedFilename != "download" {
                filename = suggestedFilename
            } else if let lastComponent = response.url?.lastPathComponent, !lastComponent.isEmpty {
                filename = lastComponent
            } else {
                filename = "download"
            }
            
            downloadTitles[download] = suggestedFilename
            downloadFrom[download] = response.url?.absoluteString

            let panel = NSSavePanel()
            panel.nameFieldStringValue = filename

            panel.begin { [weak self] result in
                    if result == .OK, let url = panel.url {
                        // SET DOWNLOAD TO HERE:
                        // Store the path where the file is actually going to be saved
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
                DispatchQueue.main.async {
                    createNewTab(with: url)
                }
            }
            return nil
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
    }
}
