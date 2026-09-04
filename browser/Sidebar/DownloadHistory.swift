import SwiftUI

struct Download: Codable, Identifiable {
    var id = UUID()
    var title: String
    var from: String
    var to:String
    var time: Date
}


// --- UI Components ---

struct DownloadRow: View {
    let Download: Download
    let action: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    CachedAsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(Download.from)"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Download.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(Download.to)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Text(Download.from)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct DownloadsView: View {
    @StateObject private var downloadStore: DownloadStore
    
    init(profile: String = "") {
        self._downloadStore = StateObject(wrappedValue: DownloadStore(profile: profile))
    }
    
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345
    
    @State private var showAddSheet = false
    @State private var urlInput: String = ""
    @State private var titleInput: String = ""
    
    @State private var searchText: String = ""
    
    var filteredHistory: [Download] {
        if searchText.isEmpty {
            return downloadStore.items
        }
        
        return downloadStore.items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        
        VStack {
            HStack {
                Text("Downloads")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Clear All") {
                    for item in Array(downloadStore.items) {
                        downloadStore.remove(id: item.id)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            VStack(spacing: 0) {

                SearchInputView(text:$searchText)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                ScrollView {
                    if downloadStore.items.isEmpty {
                        EmptyDownloadsView()
                            .padding(.top, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(filteredHistory) { mark in
                                DownloadRow(
                                    Download: mark,
                                    action: {
                                        revealDownload(mark)
                                    },
                                    onDelete: { downloadStore.remove(id: mark.id) }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
                .frame(minWidth: CGFloat(sidebarWidth))
                
                
            }
            .background(Color.black.opacity(0.03))
        }
    }

    private func revealDownload(_ download: Download) {
        let url: URL
        if let storedURL = URL(string: download.to), storedURL.isFileURL {
            url = storedURL
        } else {
            // Older download records store a plain POSIX path rather than a file URL.
            url = URL(fileURLWithPath: download.to)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            NSSound.beep()
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// --- Supporting Views ---

struct EmptyDownloadsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No Downloads Yet")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
