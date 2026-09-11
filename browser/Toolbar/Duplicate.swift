import SwiftUI

struct DuplicateToolbarButton: View {
    
    @Binding var location: URL?
    var expandedLabel = false
 
    var body: some View {
        
        Menu() {
                Text("Duplicate Tab")
                    .disabled(true)
            if let u = location {

            Button("In This Window", systemImage: "plus.square.on.square") {
                createNewTab(with: u)
            }
            Button("In New Window", systemImage: "macwindow.badge.plus") {
                createNewWindow(with: u)
            }
            
            
               
            } else {
                Text("Cannot Duplicate Tab")
                    .disabled(true)
            }
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Duplicate", systemImage: "plus.square.on.square")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
    }
}
