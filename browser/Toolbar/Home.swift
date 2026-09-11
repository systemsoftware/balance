import SwiftUI


struct HomeToolbarButton: View {
    
    @Binding var location: URL?
    @Binding var urlInput: String
    var expandedLabel = false
    
    var body: some View {
            Button {
                location = nil
                urlInput = ""
            } label: {
                ToolbarItemLabel(expanded: expandedLabel, title: "Home", systemImage: "house")
            }
            .buttonStyle(.plain)
            .frame(width: expandedLabel ? nil : 40, height: 40)
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(location == nil)
        }
    
}
