import SwiftUI


struct BookmarkBar: View {
    
    var bookmarkStore: BookmarkStore
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(bookmarkStore.items) { mark in
                    Button {
                        createNewTab(with:URL(string:mark.url))
                    } label: {
                        HStack {
                            Favicon(mark.url)
                            Text(mark.title)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove \(mark.title) Bookmark") {
                            bookmarkStore.remove(id: mark.id)
                        }
                    }
                }
            }
        }
        .glassEffect(.regular.interactive(), in:.capsule)
        .padding(.horizontal, Layout.outerPadding+5)
    }
    
}
