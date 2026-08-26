import SwiftUI

struct CommandPaletteToolbarButton: View {
    
    @State var showCommands = false
    @Binding var urlInput: String
    @State var commandSearchText = ""
    
    var body: some View {
     
        Button() {
            showCommands = true
        } label: {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.title2)
                .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in:.circle)
        .keyboardShortcut("k", modifiers: .command)
        .sheet(isPresented: $showCommands) {
            VStack(spacing: 0) {
                CommandsView(searchText:$commandSearchText, searchQuery: $urlInput)
                Button("Close") {
                    showCommands = false
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        
    }
}
