import SwiftUI

struct SaveToToolbarButton: View {
    
    @Binding var location: URL?
    @ObservedObject var sidebarStore: SidebarStore
    @ObservedObject var bookmarkStore: BookmarkStore
    
    var body: some View {
        
        Menu() {
                Text("Add Page To")
                    .disabled(true)
                
                Button("Bookmarks", systemImage: "star") {
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
        } label: {
            Image(systemName: "star.fill")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!(location?.absoluteString.starts(with: "http") ?? false))
    }
}
