import SwiftUI
import WebKit

struct RestyleToolbarButton: View {
    var expandedLabel = false
    let presentRestyleSheet: () -> Void
    
    var body: some View {
        Button {
            presentRestyleSheet()
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Restyle Page", systemImage: "paintpalette.fill")
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
    }
}
