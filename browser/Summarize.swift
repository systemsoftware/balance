import SwiftUI
import WebKit
import FoundationModels

func createSummaryWindow(state:BrowserState) async {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Summary of \(state.title)"
    window.isReleasedWhenClosed = false
    
    let text = await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            state.webView?.getCleanText { result in
                continuation.resume(returning: result ?? "")
            }
        }
    }
    
    let session = LanguageModelSession()
    
    if text.isEmpty {
        Task {
            let a = NSAlert()
            a.messageText = "No text found"
            a.runModal()
        }
        return
    }
    
    let prompt = String("Summarize this page: \(text)".prefix(3000))
    
    do {
        
        let result = try await session.respond(to: prompt).content
        
        if let url = state.url {
            let focusView = SummaryWindow(url: url, title:state.title, summary: result)
            let hostingView = NSHostingView(rootView: focusView)

            hostingView.frame = NSRect(x: 0, y: 0, width: 700, height: 1000)
            hostingView.layoutSubtreeIfNeeded()

            let size = hostingView.fittingSize

            window.setContentSize(size)
            window.contentView = hostingView

            window.center()
            
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            window.makeKeyAndOrderFront(nil)

        }
        
    } catch {
        print(error)
    }
}

struct SummaryWindow: View {
    let url: URL
    let title: String
    let summary: String

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    header

                    Divider()

                    summaryCard

                    footer
                }
                .padding(24)
                
                .frame(width: 700)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(3)

            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(summary)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.escape)
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}
