import SwiftUI

struct Bookmark: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var url: String
}


struct BookmarkRow: View {
    let bookmark: Bookmark
    let action: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(bookmark.url)"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(bookmark.url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Removes the default button "flash"
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct BookmarksView: View {
    @StateObject private var store = BookmarkStore()
    
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345

    @State var showAddSheet: Bool = false
    @Binding var showAddBookmark: Bool
    @State private var urlInput: String = ""
    @State private var titleInput: String = ""
    
    var isSettings = false

    var body: some View {
        VStack(spacing: 0) {
            
            if !isSettings {
                HStack {
                    Text("Bookmarks")
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    
                    Button() {
                        showAddSheet = true
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal)
                .padding(.top)
            }

            
            ScrollView {
                if store.items.isEmpty {
                    EmptyBookmarksView()
                        .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.items) { mark in
                            BookmarkRow(
                                bookmark: mark,
                                action: { createNewTab(with: URL(string:mark.url)) },
                                onDelete: { store.remove(id: mark.id) }
                            )
                        }
                    }
                    .padding(isSettings ? 5 : 16)
                }
            }
            .frame(minWidth: CGFloat(sidebarWidth))

        }
        .background(Color.black.opacity(0.03))
        .sheet(isPresented: $showAddSheet) {
            AddBookmarkSheet(url: $urlInput, title: $titleInput) {
                let newBookmark = Bookmark(title: titleInput, url: urlInput)
                store.add(newBookmark)
                urlInput = ""
                titleInput = ""
                showAddSheet = false
            }
        }
        .sheet(isPresented: $showAddBookmark) {
            AddBookmarkSheet(url: $urlInput, title: $titleInput) {
                let newBookmark = Bookmark(title: titleInput, url: urlInput)
                store.add(newBookmark)
                urlInput = ""
                titleInput = ""
                showAddBookmark = false
            }
        }
    }
}

// --- Supporting Views ---

struct EmptyBookmarksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No Bookmarks Yet")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddBookmarkSheet: View {
    @Binding var url: String
    @Binding var title: String
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("New Bookmark")
                .font(.headline)
            
            VStack(spacing: 12) {
                TextField("URL (https://...)", text: $url)
                    .textFieldStyle(.roundedBorder)
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save Bookmark") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(url.isEmpty || title.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
