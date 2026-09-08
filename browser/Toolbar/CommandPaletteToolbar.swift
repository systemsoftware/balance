import SwiftUI

struct CommandPaletteToolbarButton: View {
    
    @Binding var showCommands: Bool
    @Binding var urlInput: String
    
    var body: some View {
     
        Button() {
            showCommands = true
        } label: {
            Image(systemName: "text.and.command.macwindow")
                .font(.title2)
                .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .keyboardShortcut("k", modifiers: .command)        
    }
}
