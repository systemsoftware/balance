import SwiftUI
import WebKit

struct ExtensionPopupWebView: NSViewRepresentable {
    let action: WKWebExtension.Action
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = action.popupWebView ?? WKWebView(frame: .zero)
        
        webView.setValue(false, forKey: "drawsBackground")
        if let scrollView = webView.enclosingScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed, the WKWebExtensionController manages the web view content
    }
}

struct ExtensionActionPopupView: View {
    let action: WKWebExtension.Action
    
    var body: some View {
        ExtensionPopupWebView(action: action)
            .onDisappear {
                action.closePopup()
            }
    }
}
