import SwiftUI
import WebKit

struct TrailToolbarButton: View {
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    
    @State var presented = false

    var body: some View {
        Button {
            presented.toggle()
        } label: {
                ToolbarItemLabel(expanded: expandedLabel, title: "Trail", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
        .sheet(isPresented: $presented) {
            TrailView(tabState: browserState)
        }
        .disabled(!(browserState.url?.absoluteString.starts(with: "http") ?? false))
    }
}
