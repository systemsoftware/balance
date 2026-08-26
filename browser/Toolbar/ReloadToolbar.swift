import SwiftUI
import WebKit

struct ReloadToolbarButton: View {
    @ObservedObject var browserState: BrowserState

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
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
                }
            }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!(browserState.url?.absoluteString.starts(with: "http") ?? false))
    }
}
