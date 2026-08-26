import SwiftUI


struct ShareToolbarButton: View {
    
    @Binding var location: URL?
    
    var body: some View {
            ShareLink(item: location ?? URL(string:"https://systemsoftware.github.io/about/balance/")!) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
                
            }
}
