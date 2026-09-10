import SwiftUI
import WebKit

struct ExtensionPopupWebView: PlatformViewRepresentable {
    let action: WKWebExtension.Action
    
    private func makeWebView() -> WKWebView {
        let webView = action.popupWebView ?? WKWebView(frame: .zero)

        #if canImport(AppKit)
        webView.setValue(false, forKey: "drawsBackground")
        if let scrollView = webView.enclosingScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
        }
        #endif
        return webView
    }

    #if canImport(AppKit)
    func makeNSView(context: Context) -> WKWebView { makeWebView() }
    func updateNSView(_ webView: WKWebView, context: Context) {
        // No updates needed, the WKWebExtensionController manages the web view content
    }
    #else
    func makeUIView(context: Context) -> WKWebView { makeWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed, the WKWebExtensionController manages the web view content
    }
    #endif
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
