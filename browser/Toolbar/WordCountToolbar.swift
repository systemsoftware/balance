import SwiftUI

struct WordCountToolbarButton: View {
    var expandedLabel = false
    let present: () -> Void
    
    var body: some View {
     
        Button() {
            present()
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Word Count", systemImage: "text.quote")
        }
        .buttonStyle(.plain)
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .keyboardShortcut("k", modifiers: .command)        
    }
}
