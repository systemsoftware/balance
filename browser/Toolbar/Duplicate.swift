import SwiftUI

struct DuplicateToolbarButton: View {
    
    @Binding var location: URL?
 
    var body: some View {
        
        Menu() {
                Text("Duplicate Tab:")
                    .disabled(true)
            if let u = location {

            Button("In This Window", systemImage: "plus.square.on.square") {
                createNewTab(with: u)
            }
            Button("In New Window", systemImage: "macwindow.badge.plus") {
                createNewWindow(with: u)
            }
            
            
            Divider()
            
                Button {
                    createFocusWindow(with: u)
                } label: {
                    Label("Open in Focus", systemImage: "macwindow")
                }
            } else {
                Text("Cannot Duplicate Tab")
                    .disabled(true)
            }
        } label: {
            Image(systemName: "plus.square.on.square")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 40, height: 40)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
    }
}
