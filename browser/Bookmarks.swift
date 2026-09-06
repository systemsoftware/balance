import SwiftUI

struct Bookmark: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: String

    init(id: UUID = UUID(), title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    var displayTitle: String {
        title.isEmpty ? url : title
    }

    var faviconURL: URL? {
        guard var components = URLComponents(string: "https://www.google.com/s2/favicons") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "domain", value: url)]
        return components.url
    }
}


struct BookmarkRow: View {
    let bookmark: Bookmark
    let action: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    CachedAsyncImage(url: bookmark.faviconURL)
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.displayTitle)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(bookmark.url)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
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
    @State private var editingBookmark: Bookmark?
    
    var isSettings = false

    var body: some View {
        VStack(spacing: 0) {
            
            if !isSettings {
                HStack {
                    Text("Bookmarks")
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    
                    Button {
                        presentNewBookmark()
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding()
            }

            
            if store.items.isEmpty {
                if isSettings {
                    EmptyBookmarksView()
                        .padding(.top, 40)
                } else {
                    ScrollView {
                        EmptyBookmarksView()
                            .padding(.top, 40)
                    }
                    .frame(minWidth: CGFloat(sidebarWidth))
                }
            } else {
                if isSettings {
                    VStack(spacing: 8) {
                        ForEach(store.items) { mark in
                            BookmarkRow(
                                bookmark: mark,
                                action: { createNewTab(with: URL(string:mark.url)) },
                                onDelete: { store.remove(id: mark.id) },
                                onEdit: {
                                    urlInput = mark.url
                                    titleInput = mark.title
                                    editingBookmark = mark
                                }
                            )
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.vertical, 8)
                } else {
                    List {
                        ForEach(store.items) { mark in
                            BookmarkRow(
                                bookmark: mark,
                                action: { createNewTab(with: URL(string:mark.url)) },
                                onDelete: { store.remove(id: mark.id) },
                                onEdit: {
                                    urlInput = mark.url
                                    titleInput = mark.title
                                    editingBookmark = mark
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onMove { source, destination in
                            store.move(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(minWidth: CGFloat(sidebarWidth))
                }
            }

        }
        .background(Color.black.opacity(0.03))
        .sheet(isPresented: $showAddSheet) {
            AddBookmarkSheet(url: $urlInput, title: $titleInput) {
                store.add(Bookmark(title: titleInput, url: urlInput))
                resetForm()
                showAddSheet = false
            }
        }
        .onChange(of: showAddBookmark) { _, shouldPresent in
            guard shouldPresent else { return }
            presentNewBookmark()
            showAddBookmark = false
        }
        .sheet(item: $editingBookmark) { mark in
            AddBookmarkSheet(url: $urlInput, title: $titleInput, isEditing: true) {
                store.update(id: mark.id, title: titleInput, url: urlInput)
                editingBookmark = nil
                resetForm()
            }
        }

    }

    private func presentNewBookmark() {
        resetForm()
        showAddSheet = true
    }

    private func resetForm() {
        urlInput = ""
        titleInput = ""
    }
}

// --- Supporting Views ---

struct EmptyBookmarksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No Bookmarks Yet")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddBookmarkSheet: View {
    @Binding var url: String
    @Binding var title: String
    var isEditing: Bool = false
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Bookmark" : "New Bookmark")
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
                
                Button("Save Bookmark") {
                    url = url.trimmingCharacters(in: .whitespacesAndNewlines)
                    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave()
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
