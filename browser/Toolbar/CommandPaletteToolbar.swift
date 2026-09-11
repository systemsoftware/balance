import SwiftUI

struct CommandPaletteToolbarButton: View {
    var expandedLabel = false
    let presentCommands: () -> Void
    
    var body: some View {
     
        Button() {
            presentCommands()
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Command Palette", systemImage: "text.and.command.macwindow")
        }
        .buttonStyle(.plain)
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .keyboardShortcut("k", modifiers: .command)        
    }
}
