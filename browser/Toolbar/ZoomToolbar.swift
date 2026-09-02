import SwiftUI

struct ZoomToolbar: View {
    
    @Binding var location: URL?
    @ObservedObject var browserState: BrowserState
    
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
            Image(systemName: "plus.magnifyingglass")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
    }
}
