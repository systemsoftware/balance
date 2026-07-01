import SwiftUI
import WebKit
import AppKit

func createFocusWindow(with url: URL, userAgent: String) {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Focus"
    window.isReleasedWhenClosed = false
    
    let focusView = FocusWebView(url: url, userAgent: userAgent)
    window.contentView = NSHostingView(rootView: focusView)
    window.makeKeyAndOrderFront(nil)
}

struct FocusWebView: View {
    let url: URL
    let userAgent: String
    @State var page = WebPage()
    
    var body: some View {
        WebView(page)
            .onAppear {
                page.customUserAgent = userAgent
                page.load(URLRequest(url: url))
            }
    }
}
