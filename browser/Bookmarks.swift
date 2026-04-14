import SwiftUI

struct Bookmark: Codable, Identifiable {
    var id = UUID()
    var title: String
    var url: String
    var folder: String?
}

struct BookmarksView: View {
    @EnvironmentObject var tabManager: TabManager
   
    @StateObject private var store = BookmarkStore()
    
    @AppStorage("sidebarWidth", store:Config.sharedDefaults)
    var sidebarWidth: Int = 300

    @State var showAddAlertURL = false
    @State var showAddAlertTitle = false
    @State var urlInput: String = ""
    @State var titleInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.items) { mark in
                            Button(action: {
                                tabManager.createNewTab(urlInput: mark.url)
                            }) {
                                HStack {
                                    Text(mark.title)
                                        .font(.system(.body, design: .rounded))
                                    Spacer()
                                }
                                .padding()
                            }
                            .roundedBorderStyle()
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    store.remove(id: mark.id)
                                }
                            }
                    }
                }.frame(width:CGFloat(sidebarWidth))
            }


            GlassCard {
                Button(action: { showAddAlertURL = true }) {
                    Label("Add Bookmark", systemImage: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
            }
            .padding()
        }

        .background(Color.black.opacity(0.1))
        
        // Alerts...
        .alert("Enter URL", isPresented: $showAddAlertURL) {
            TextField("URL", text: $urlInput)
            Button("Next") {
                showAddAlertURL = false
                showAddAlertTitle = true
            }
            Button("Cancel", role: .cancel) { urlInput = "" }
        }
        .alert("Enter Title", isPresented: $showAddAlertTitle) {
            TextField("Title", text: $titleInput)
            Button("Save") {
                let newBookmark = Bookmark(title: titleInput, url: urlInput)
                store.add(newBookmark)
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
