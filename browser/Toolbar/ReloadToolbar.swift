import SwiftUI
import WebKit

struct ReloadToolbarButton: View {
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false

    var body: some View {
        Button {
            if browserState.isLoading {
                browserState.webView?.stopLoading()
            } else {
                browserState.webView?.reload()
            }
        } label: {
            Group {
                if browserState.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
                } else {
                    ToolbarItemLabel(expanded: expandedLabel, title: "Reload", systemImage: "arrow.clockwise")
                }
            }
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
        .disabled(!(browserState.url?.absoluteString.starts(with: "http") ?? false))
    }
}
