import SwiftUI

struct SaveToToolbarButton: View {
    
    @Binding var location: URL?
    @ObservedObject var sidebarStore: SidebarStore
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    
    var body: some View {
        
        Menu() {
                Button("Bookmark", systemImage: "star") {
                    bookmarkStore.add(Bookmark(
                        title: location?.host() ?? "Unnamed",
                        url: location?.absoluteString ?? "https://example.com"
                    ))
                }
                
                Button("Sidebar", systemImage: "sidebar.left") {
                    sidebarStore.add(SidebarItem(
                        icon: location?.host ?? "globe",
                        url: location
                    ))
                }
            
                Divider()
            
            Button("PDF") {
                browserState.exportWebViewToPDF()
            }
            
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Save To", systemImage: "star.fill")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
    }
}
