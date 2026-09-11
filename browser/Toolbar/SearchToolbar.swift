import SwiftUI


struct SearchToolbarButton: View {
    
    @Binding var location: URL?
    var expandedLabel = false
    let submitURL: () -> Void
    
    var body: some View {
        
            HStack(spacing: 12) {
                Button(action: submitURL) {
                    ToolbarItemLabel(expanded: expandedLabel, title: "Go", systemImage: "arrow.turn.down.right")
                }
                .frame(width: expandedLabel ? nil : 40, height: 40)
                .buttonStyle(.plain)
            }

    }
}
