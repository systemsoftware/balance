import SwiftUI
import WebKit

struct TabsToolbarButton: View {
    @EnvironmentObject private var windowManager: WindowManager

    var expandedLabel = false
    
    var body: some View {
        Button {
            MemoryStorage.shared.showTabOverview.toggle()
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Tab Overview", systemImage: "square.on.square")
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .disabled(windowManager.windows.count <= 1)
        .buttonStyle(.plain)
    }
}
