import SwiftUI


struct SearchToolbarButton: View {
    
    @Binding var location: URL?
    
    let submitURL: () -> Void
    
    var body: some View {
        
            HStack(spacing: 12) {
                Button(action: submitURL) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.title2)
                        .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
                }
                .frame(width: 40, height: 40)
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }

    }
}
