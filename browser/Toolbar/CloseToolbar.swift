import SwiftUI


struct CloseToolbarButton: View {
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    @EnvironmentObject var windowManager: WindowManager
    
    var body: some View {
        Button {
            windowManager.closeTab(browserState.tabID)
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Close Tab", systemImage: "xmark")
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
    }
}
