import SwiftUI

struct FindBarView: View {
    @ObservedObject var state: BrowserState
    
    @Namespace private var glassNamespace

    
    init(state: BrowserState) {
        self.state = state
    }
    
    var body: some View {
        HStack(spacing: 6) {
            TextField("Find in page", text: $state.findQuery)
                .textFieldStyle(.plain)
                .frame(width: 200)
                .onSubmit { state.find(state.findQuery) }
                .onChange(of: state.findQuery) { query in
                    state.find(query)
                }
                .padding(Layout.controlPadding)

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
                state.findQuery = ""
                state.clearFind()
                state.isFindBarVisible = false
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
}
