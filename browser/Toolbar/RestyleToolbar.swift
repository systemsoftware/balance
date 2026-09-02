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
        .frame(width: 40, height: 40)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}
