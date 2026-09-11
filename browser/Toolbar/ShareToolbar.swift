import SwiftUI


struct ShareToolbarButton: View {
    
    @Binding var location: URL?
    var expandedLabel = false
    
    var body: some View {
            ShareLink(item: location ?? URL(string:"https://systemsoftware.github.io/about/balance/")!) {
                    ToolbarItemLabel(expanded: expandedLabel, title: "Share", systemImage: "square.and.arrow.up")
                }
                .frame(width: expandedLabel ? nil : 40, height: 40)
                .buttonStyle(.plain)
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
                
            }
}
