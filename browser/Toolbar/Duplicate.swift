import SwiftUI

struct DuplicateToolbarButton: View {
    
    @Binding var location: URL?
    var expandedLabel = false
 
    var body: some View {
        
        Menu {
            Button("In This Window", systemImage: "plus.square.on.square") {
                if let u = location {
                    createNewTab(with: u)
                } else {
                    createNewTab()
                }
            }
            Button("In New Window", systemImage: "macwindow.badge.plus") {
                if let u = location {
                    createNewWindow(with: u)
                } else {
                    createNewWindow()
                }
            }
    
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Duplicate", systemImage: "plus.square.on.square")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: expandedLabel ? nil : 40, height: 40)
    }
}
