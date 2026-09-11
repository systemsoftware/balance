import SwiftUI
import WebKit

struct ToolbarCommandsSheet: View {
    @Binding var searchText: String
    @Binding var searchQuery: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            CommandsView(searchText: $searchText, searchQuery: $searchQuery)
            Button("Close") { dismiss() }
                .padding()
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }
}

struct ToolbarTabSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TabSearchView(isPopover: true)
            Button("Close") { dismiss() }
                .padding()
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }
}

struct ToolbarGoToSheet: View {
    @Binding var urlInput: String
    let submitURL: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            TextField("Enter URL", text: $urlInput)
                .textFieldStyle(.roundedBorder)
                .padding()
            HStack {
                Button("Cancel") { dismiss() }
                Button("Go") {
                    dismiss()
                    submitURL()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

struct ToolbarSplitURLSheet: View {
    @Binding var splitURL: String
    @State private var draftURL = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Split View URL")
                .font(.headline)
            Text("Enter the URL to show beside the current page.")
                .foregroundStyle(.secondary)
            TextField("https://example.com", text: $draftURL)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Go") {
                    if !draftURL.hasPrefix("http") {
                        splitURL = "https://" + draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        splitURL = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .onAppear { draftURL = splitURL }
    }
}

struct ToolbarRenameSheet: View {
    @ObservedObject var browserState: BrowserState
    @State private var newName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            TextField("Enter new tab name:", text: $newName)
                .textFieldStyle(.roundedBorder)
                .padding()
            HStack {
                Button("Cancel") { dismiss() }
                Button("Rename") {
                    let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedName.isEmpty {
                        browserState.customTitle = nil
                        browserState.title = browserState.webView?.title ?? "Page"
                    } else {
                        browserState.customTitle = trimmedName
                        browserState.title = trimmedName
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear { newName = browserState.customTitle ?? "" }
    }
}

struct ToolbarSummarySheet: View {
    
    @ObservedObject var browserState: BrowserState
    @Binding var isSummarizing: Bool
    @State var result = ""
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            if result.isEmpty {
                ProgressView("Generating summary...")
                    .frame(width: 700, height: 400)
            } else {
                
                SummaryWindow(url: browserState.url ?? URL(string:"https://example.com")!, title:browserState.title, summary: result)
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.red)
            }
        }
            .task {
                isSummarizing = true
                defer { isSummarizing = false }
                do {
                    result = try await generatePageSummary(state: browserState)
                } catch {
                    result = error.localizedDescription
                }
            }
    }
    
}
