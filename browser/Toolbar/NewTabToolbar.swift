import SwiftUI
import WebKit

struct NewTabToolbarButton: View {
    var expandedLabel = false

    var body: some View {
        Button {
            createNewTab()
        } label: {
                ToolbarItemLabel(expanded: expandedLabel, title: "New Tab", systemImage: "plus.square.on.square")
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
    }
}
