import SwiftUI

struct FindBarView: View {
    @ObservedObject var state: BrowserState
    
    @Namespace private var glassNamespace
    @State private var pendingSearch: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 6) {
            TextField("Find in page",
                text: $state.findQuery,
            )
            .textFieldStyle(.plain)
            .padding(5)
            .frame(width: 200)
            .onChange(of: state.findQuery) { old, query in
                pendingSearch?.cancel()
                guard !query.isEmpty else {
                    state.clearFind()
                    return
                }
                pendingSearch = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled, state.findQuery == query else { return }
                    state.find(query)
                }
            }
            .padding(Layout.controlPadding)

            if !state.findQuery.isEmpty && state.findMatchCount == 0 {
                Text("No results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: { findNext(forward: false) }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(state.findQuery.isEmpty)

            Button(action: { findNext(forward: true) }) {
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
        .onDisappear {
            pendingSearch?.cancel()
        }
    }

    private func findNext(forward: Bool) {
        pendingSearch?.cancel()
        state.find(state.findQuery, forward: forward)
    }

    private func dismissFindBar() {
        // The native search field may still be AppKit's first responder. Removing
        // its hosting view synchronously can corrupt the key-view loop.
        NSApp.keyWindow?.makeFirstResponder(nil)
        Task { @MainActor in
            await Task.yield()
            state.findQuery = ""
            state.isFindBarVisible = false
        }
    }
}
