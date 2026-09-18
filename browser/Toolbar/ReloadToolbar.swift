import SwiftUI
import WebKit

struct ReloadToolbarButton: View {
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    @State private var displayedIsLoading: Bool

    init(browserState: BrowserState, expandedLabel: Bool = false) {
        self.browserState = browserState
        self.expandedLabel = expandedLabel
        _displayedIsLoading = State(initialValue: browserState.isLoading)
    }

    var body: some View {
        Button {
            if browserState.isLoading {
                browserState.webView?.stopLoading()
            } else {
                browserState.webView?.reload()
            }
        } label: {
            ToolbarItemLabel(
                expanded: expandedLabel,
                title: displayedIsLoading ? "Stop" : "Reload",
                systemImage: displayedIsLoading ? "progress.indicator" : "arrow.clockwise"
            )
            .symbolEffect(.rotate, isActive: browserState.isLoading)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
        .disabled(browserState.url != nil)
        .task(id: browserState.isLoading) {
            if browserState.isLoading {
                displayedIsLoading = true
            } else {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, !browserState.isLoading else { return }
                displayedIsLoading = false
            }
        }
    }
}
