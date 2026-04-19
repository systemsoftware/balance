import SwiftUI
import AppKit

struct Download: Codable, Identifiable {
    var id = UUID()
    var title: String
    var from: String
    var to:String
    var time: Date
}

import SwiftUI

// --- UI Components ---

struct DownloadRow: View {
    let Download: Download
    let action: () -> Void
    let onDelete: () -> Void
    
    @StateObject var downloadStore = DownloadStore()

    var body: some View {
        
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
        
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(Download.from)"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Download.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(Download.to)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(Download.from)
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
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct DownloadsView: View {
    @StateObject private var store = DownloadStore()
    
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 300

    @State private var showAddSheet = false
    @State private var urlInput: String = ""
    @State private var titleInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if store.items.isEmpty {
                    EmptyDownloadsView()
                        .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.items) { mark in
                            DownloadRow(
                                Download: mark,
                                action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(string:mark.to)!])
                                },
                                onDelete: { store.remove(id: mark.id) }
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
