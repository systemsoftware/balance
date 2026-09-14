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
                
                ToolbarItemLabel(expanded: expandedLabel, title: "Reload", systemImage: browserState.isLoading ? "progress.indicator" : "arrow.clockwise")
                    .symbolEffect(.rotate, isActive: browserState.isLoading)
                                  .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
        
            }
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
        .disabled(!(browserState.url?.absoluteString.starts(with: "http") ?? false))
    }
}
