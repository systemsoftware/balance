import SwiftUI
import WebKit
import AppKit
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
    
    let prompt = String("Summarize this page: \(text)".prefix(3000))
    
    do {
        
        let result = try await session.respond(to: prompt).content
        
        if let url = state.url {
            let focusView = SummaryWindow(url: url, title:state.title, summary: result)
            window.contentView = NSHostingView(rootView: focusView)
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
        VStack {
            Text(title)
                .font(.headline)

            Text(summary)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: 500, maxHeight: 300)
    }
    
}
