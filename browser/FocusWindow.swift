import SwiftUI
import WebKit
import AppKit

func createFocusWindow(with url: URL, userAgent: String) {
    let window = NSWindow(
        contentRect: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Focus"
    window.isReleasedWhenClosed = false
    
    let focusView = FocusWebView(url: url, userAgent: userAgent, window: window)
    window.contentView = NSHostingView(rootView: focusView)
    window.makeKeyAndOrderFront(nil)
}

struct FocusWebView: View {
    let url: URL
    let userAgent: String
    weak var window: NSWindow?
    @State var page = WebPage()
    
    var body: some View {
        WebView(page)
            .onAppear {
                page.customUserAgent = userAgent
                page.load(URLRequest(url: url))
            }
            .onChange(of: page.title) { _, newTitle in
                if !newTitle.isEmpty {
                    window?.title = "\(newTitle) - Focus"
                } else {
                    window?.title = "Focus"
                }
            }
    }
}
