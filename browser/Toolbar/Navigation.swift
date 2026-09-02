import SwiftUI
import WebKit

struct NavigationButtons: View {
    
    @Namespace private var backforwardNamespace

    @Binding var location: URL?
    @ObservedObject var browserState: BrowserState
    
    var body: some View {
            GlassEffectContainer {
                HStack(spacing: 0) {
                        Button(action: {
                            browserState.webView?.goBack()
                        }) {
                            Image(systemName: "chevron.backward")
                                .padding(Layout.controlPadding)
                                .font(.title2)
                        }
                        .padding(8)
                        .frame(height: 40)
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())
                        .glassEffectUnion(id: "backforward", namespace: backforwardNamespace)
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                        .disabled(location == nil ||  !browserState.canGoBack)
                        .contextMenu {
                            if let webView = browserState.webView {
                                let list = Array(webView.backForwardList.backList.reversed())
                                ForEach(list, id: \.self) { item in
                                    Button(item.url.absoluteString) {
                                        location = item.url
                                    }
                                }
                            }
                    }
                    
                        Button(action: {
                            Task {
                                browserState.webView?.goForward()
                            }
                        }) {
                            Image(systemName: "chevron.forward")
                                .padding(Layout.controlPadding)
                                .font(.title2)
                        }
                        .padding(8)
                        .frame(height: 40)
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())
                        .glassEffectUnion(id: "backforward", namespace: backforwardNamespace)
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                        .disabled(location == nil || !browserState.canGoForward)
                        .contextMenu {
                            if let webView = browserState.webView {
                                let list = Array(webView.backForwardList.forwardList.reversed())
                                ForEach(list, id: \.self) { item in
                                    Button(item.url.absoluteString) {
                                        location = item.url
                                    }
                                }
                            }
                        }
                }
            }
        }
}
