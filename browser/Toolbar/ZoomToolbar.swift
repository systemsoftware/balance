import SwiftUI

struct ZoomToolbar: View {
    
    @Binding var location: URL?
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    
    var body: some View {
        
        Menu() {
            Button() {
                browserState.zoomIn()
            } label: {
                Label("In", systemImage:"plus.magnifyingglass")
            }
            
            Button() {
                browserState.zoomOut()
            } label: {
                Label("Out", systemImage:"minus.magnifyingglass")
            }
            
            Divider()
            
            Button() {
                browserState.resetZoom()
            } label: {
                Label("Reset", systemImage: "arrow.clockwise.circle")
            }

        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Zoom", systemImage: "plus.magnifyingglass")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
    }
}
