import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

struct Download: Codable, Identifiable {
    var id = UUID()
    var title: String
    var from: String
    var to:String
    var time: Date
    var failureDescription: String? = nil
    var resumeData: Data? = nil
    var temporaryPaths: [String]? = nil
}


// --- UI Components ---

struct DownloadRow: View {
    let Download: Download
    let action: () -> Void
    let onDelete: () -> Void
    let onResume: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Favicon(Download.from)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Download.title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if let failure = Download.failureDescription {
                        Text(failure)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                    
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
                
                Image(systemName: Download.resumeData == nil ? "chevron.right" : "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.platformWindowBackground.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if Download.resumeData != nil {
                Button("Resume", action: onResume)
            }
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
    @State private var resumeError: String?
    
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
                        downloadStore.discard(id: item.id)
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
                if let resumeError {
                    Text(resumeError).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }

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
                                        if mark.resumeData != nil { resumeDownload(mark) }
                                        else { revealDownload(mark) }
                                    },
                                    onDelete: { downloadStore.discard(id: mark.id) },
                                    onResume: { resumeDownload(mark) }
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
            #if canImport(AppKit)
            NSSound.beep()
            #else
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            return
        }

        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func resumeDownload(_ item: Download) {
        guard let resumeData = item.resumeData else { return }
        let candidate = WindowManager.shared.browserWindows
            .flatMap(\.tabs)
            .first { $0.profile == downloadStore.profileName && !$0.isPrivate
                && ($0.browserState.webView ?? $0.browserState.underlyingWebView) != nil }
        guard let webView = candidate?.browserState.webView ?? candidate?.browserState.underlyingWebView,
              let coordinator = webView.navigationDelegate as? BrowserWebView.Coordinator else {
            resumeError = "Open a tab in this profile to resume the download."
            return
        }
        resumeError = nil
        coordinator.resumeFailedDownload(item, resumeData: resumeData, in: webView)
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
