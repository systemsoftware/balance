import SwiftUI
import WebKit

struct RestyleToolbarButton: View {
    
    @Binding var showBoost: Bool
    
    var body: some View {
        Button {
            showBoost.toggle()
        } label: {
            Image(systemName: "paintpalette.fill")
                .font(.title2)
                .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}
