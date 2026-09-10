import SwiftUI


struct ExtensionsToolbarButton: View {
    
    @ObservedObject var browserState: BrowserState
    @Binding var location: URL?
    @State var showExtensionsPopover = false
    @AppStorage("toolbarLocation") private var toolbarLocation = 0
    
    var body: some View {
            Button(action: {
                showExtensionsPopover.toggle()
            }) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.title2)
                    .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
            }
            .buttonStyle(.plain)
            .frame(width: 40, height: 40)
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(browserState.url == nil || browserState.url?.isFileURL == true)
            .popover(
                isPresented: $showExtensionsPopover,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: toolbarLocation == 0 ? .top : .bottom
            ) {
                ExtensionsPopoverView()
                    .roomyToolbarPopover(minHeight: 420)
            }

    }
}
