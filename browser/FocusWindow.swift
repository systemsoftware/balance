import SwiftUI
import WebKit

func createFocusWindow(with url: URL) {
    let window = NSWindow(
        contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.closable, .miniaturizable, .resizable],
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
    @AppStorage("userAgent", store:Config.sharedDefaults) var userAgent = ""
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
