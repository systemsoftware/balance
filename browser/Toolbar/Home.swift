import SwiftUI


struct HomeToolbarButton: View {
    
    @Binding var location: URL?
    @Binding var urlInput: String
    
    var body: some View {
            Button {
                location = nil
                urlInput = ""
            } label: {
                Image(systemName:"house")
                    .font(.title2)
                    .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
            }
            .buttonStyle(.plain)
            .frame(width: 40, height: 40)
            .glassEffect(.regular.interactive(), in: .circle)
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(location == nil)
        }
    
}
