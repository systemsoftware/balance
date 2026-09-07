import SwiftUI
import WebKit

// TO BE REMOVED SOON

func createFocusWindow(with url: URL) {
    let window = NSWindow(
        contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled,.closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Focus"
    window.isReleasedWhenClosed = false
    
    let focusView = FocusWebView(url: url, window: window)
    window.contentView = NSHostingView(rootView: focusView)
    window.makeKeyAndOrderFront(nil)
}

struct FocusWebView: View {
    let url: URL
    @AppStorage("userAgent", store:Config.sharedDefaults)
    private var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    weak var window: NSWindow?
    @StateObject var page = BrowserState()
    
    @State var request = URLRequest(url: URL(string: "about:blank")!)
    
    var body: some View {
        BrowserWebView(request: request, state: page)
            .onAppear {
                request = URLRequest(url: url)
                
                if let web = page.webView {
                    web.customUserAgent = userAgent
                } else {
                    print("cant set ua for focus")
                }
                
            }
            .onChange(of: page.title) { _, newTitle in
                
                if let web = page.webView {
                    web.customUserAgent = userAgent
                } else {
                    print("cant set ua for focus")
                }
                
                if !newTitle.isEmpty {
                    window?.title = "\(newTitle) (Focus)"
                } else {
                    window?.title = "Focus"
                }
            }
    }
}
