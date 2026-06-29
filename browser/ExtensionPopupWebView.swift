import SwiftUI
import WebKit

struct ExtensionPopupWebView: NSViewRepresentable {
    let action: WKWebExtension.Action
    
    func makeNSView(context: Context) -> WKWebView {
        // Fallback to a new WKWebView if popupWebView is nil (shouldn't happen if presentsPopup is checked)
        let webView = action.popupWebView ?? WKWebView(frame: .zero)
        
        // Disable scrolling in the popup to feel more native, unless the content requires it
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

// Wrapper to handle onDisappear for cleanup
struct ExtensionActionPopupView: View {
    let action: WKWebExtension.Action
    
    var body: some View {
        ExtensionPopupWebView(action: action)
            .onDisappear {
                action.closePopup()
            }
    }
}
