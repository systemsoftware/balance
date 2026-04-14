import SwiftUI

struct Bookmark: Codable, Identifiable {
    var id = UUID()
    var title: String
    var url: String
    var folder: String?
}

struct BookmarkStorage: Codable, RawRepresentable {
    var items: [Bookmark]

    init(items: [Bookmark]) {
        self.items = items
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return nil }
        self.items = decoded
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(items),
              let str = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }
}

struct BookmarksView: View {

    @EnvironmentObject var tabManager: TabManager
    
    @AppStorage("bookmarks") var bookmarks = BookmarkStorage(items: [])

    @State var showAddAlertURL = false
    @State var showAddAlertTitle = false

    @State var urlInput: String = ""
    @State var titleInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bookmarks.items) { mark in
                        Button(action: {
                            tabManager.createNewTab(urlInput: mark.url)
                        }) {
                            HStack {
                                Text(mark.title)
                                Spacer()
                            }
                            .buttonStyle(.glass)
                            .padding()
                        }
                        .contextMenu {
                            Button("Remove") {
                                bookmarks.items.removeAll { $0.id == mark.id }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }


            GlassCard {
                Button(action: { showAddAlertURL = true }) {
                    Label("Add Bookmark", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(Color.black.opacity(0.1))

        .alert("Enter URL", isPresented: $showAddAlertURL) {
            TextField("URL", text: $urlInput)
            Button("Next") {
                showAddAlertURL = false
                showAddAlertTitle = true
            }
            Button("Cancel", role: .cancel) {
                urlInput = ""
            }
        }

        .alert("Enter Title", isPresented: $showAddAlertTitle) {
            TextField("Title", text: $titleInput)
            Button("Save") {
                let newBookmark = Bookmark(title: titleInput, url: urlInput)
                bookmarks.items.append(newBookmark)
                urlInput = ""
                titleInput = ""
            }
            Button("Cancel", role: .cancel) {
                urlInput = ""
                titleInput = ""
            }
        }
    }
}


