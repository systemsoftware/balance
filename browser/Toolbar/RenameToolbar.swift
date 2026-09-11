import SwiftUI
import WebKit

struct RenameToolbar: View {
    
    @Binding var location: URL?
    let presentRenameSheet: () -> Void
    var expandedLabel = false
    
    var body: some View {
        
        Button() {
            presentRenameSheet()
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Rename Tab", systemImage: "pencil")
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .disabled(location == nil)
    }
}
