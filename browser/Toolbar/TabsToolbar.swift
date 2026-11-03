import SwiftUI
import WebKit

struct TabsToolbarButton: View {
    var expandedLabel = false
    let presentSheet: () -> Void
    
    var body: some View {
        Button {
            presentSheet()
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Tab Overview", systemImage: "rectangle.on.rectangle")
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
    }
}
