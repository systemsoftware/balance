import SwiftUI

struct FindBarView: View {
    @ObservedObject var state: BrowserState
    
    @Namespace private var glassNamespace
    
    var body: some View {
        HStack(spacing: 6) {
            NativeSearchField(
                text: $state.findQuery,
                placeholder: "Find in page",
                onFocusChange: { _ in }
            )
            .padding(5)
            .frame(width: 200)
            .onChange(of: state.findQuery) { old, query in
                state.find(query)
            }
            .padding(Layout.controlPadding)

            if !state.findQuery.isEmpty && state.findMatchCount == 0 {
                Text("No results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: { state.find(state.findQuery, forward: false) }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(state.findQuery.isEmpty)

            Button(action: { state.find(state.findQuery) }) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(state.findQuery.isEmpty)

            Button(action: {
                dismissFindBar()
            }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect()
        .glassEffectUnion(id: "find", namespace: glassNamespace)
    }

    private func dismissFindBar() {
        // The native search field may still be AppKit's first responder. Removing
        // its hosting view synchronously can corrupt the key-view loop.
        NSApp.keyWindow?.makeFirstResponder(nil)
        Task { @MainActor in
            await Task.yield()
            state.findQuery = ""
            state.clearFind()
            state.isFindBarVisible = false
        }
    }
}
