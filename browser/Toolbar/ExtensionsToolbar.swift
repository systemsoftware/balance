import SwiftUI


struct ExtensionsToolbarButton: View {
    
    @ObservedObject var browserState: BrowserState
    @Binding var location: URL?
    @State var showExtensionsPopover = false
    
    var body: some View {
            Button(action: {
                showExtensionsPopover.toggle()
            }) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.title2)
                    .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(browserState.url == nil || browserState.url?.isFileURL == true)
            .popover(isPresented: $showExtensionsPopover, arrowEdge: .bottom) {
                ExtensionsPopoverView()
            }

    }
}
