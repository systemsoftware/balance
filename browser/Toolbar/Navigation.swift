import SwiftUI
import WebKit

struct NavigationButtons: View {
    
    @Binding var location: URL?
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    
    var body: some View {
                HStack(spacing: 0) {
                        Button(action: {
                            browserState.webView?.goBack()
                        }) {
                            navigationLabel("Back", systemImage: "chevron.backward")
                        }
                        .frame(width: expandedLabel ? nil : 40, height: 40)
                        .buttonStyle(.plain)
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
                            navigationLabel("Forward", systemImage: "chevron.forward")
                        }
                        .frame(width: expandedLabel ? nil : 40, height: 40)
                        .buttonStyle(.plain)
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

    @ViewBuilder
    private func navigationLabel(_ title: String, systemImage: String) -> some View {
        if expandedLabel {
            Label(title, systemImage: systemImage)
        } else {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(height: Layout.toolbarButtonSize)
        }
    }
}
