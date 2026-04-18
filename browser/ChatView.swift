import SwiftUI
import FoundationModels
import WebKit

private let model = SystemLanguageModel.default

struct ChatItem: Identifiable {
    let id = UUID()
    let query: String
    let response: String
}

func getCleanText(from webView: WKWebView, completion: @escaping (String?) -> Void) {
    let jsCode = """
        (function() {
            // innerText excludes <script> and <style> by default
            let text = document.body.innerText; 
            // Remove excessive newlines and tabs to save tokens
            return text.replace(/\\t+/g, ' ')
                       .replace(/\\n{3,}/g, '\\n\\n')
                       .trim();
        })()
    """
    
    webView.evaluateJavaScript(jsCode) { (result, error) in
        if let error = error {
            print("Extraction error: \(error.localizedDescription)")
            completion(nil)
            return
        }
        completion(result as? String)
    }
}


struct ChatView: View {
    @AppStorage("instructions", store: Config.sharedDefaults) var inst: String = ""
    @AppStorage("temp", store: Config.sharedDefaults) var temp: Double = 0.7
    @AppStorage("maxTokens", store: Config.sharedDefaults) var maxTokens: Int = 1000
    
    @State var chat: [ChatItem] = []
    @State private var query: String = ""
    @State var session: LanguageModelSession? = LanguageModelSession()
    @State var hasSession = false
    
    var contentView: ContentView
    
    init(contentV:ContentView) {
        contentView = contentV
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Model Availability Logic
            Group {
                switch model.availability {
                case .available:
                    chatContent
                case .unavailable(.deviceNotEligible):
                    errorPlaceholder("Device not eligible for Foundation Models.")
                case .unavailable(.appleIntelligenceNotEnabled):
                    errorPlaceholder("Enable Apple Intelligence in Settings.")
                case .unavailable(.modelNotReady):
                    errorPlaceholder("Model is downloading/preparing...")
                case .unavailable(_):
                    errorPlaceholder("Language model unavailable.")
                }
            }
            
            // 2. Persistent Input Area at Bottom
            inputBar
        }
        .background(Color.black.opacity(0.1)) // Subtle depth for sidebar
    }

    // Scrollable Chat History
    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(chat) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.query.replacingOccurrences(of: String(CurrentPage.prefix(12000)), with: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            GlassCard {
                                Text(.init(item.response))
                                    .font(.system(.body, design: .rounded))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .id(item.id)
                    }
                }
                .padding()
            }
        }
    }
    
    @State var CurrentPage: String = ""

    // Bottom Input Bar
    private var inputBar: some View {
        VStack{
            Button("Add Current Page") {
                if let webView = contentView.browserState.webView {
                    
                    // 2. Call the function with the completion block
                    getCleanText(from: webView) { cleanedText in
                        
                        // 3. Assign the result inside the brackets
                        if let content = cleanedText {
                            self.CurrentPage = content
                        }
                    }
                }
            }
            GlassCard {
                HStack(spacing: 10) {
                    TextField("Query", text: $query)
                        .textFieldStyle(.plain)
                        .submitLabel(.send)
                        .onSubmit(sendMessage)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                    
                    Button(action: resetSession) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding()
        }
    }

    // Helper for errors
    private func errorPlaceholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            Spacer()
        }
    }

    // Logic Functions
    private func sendMessage() {
        guard !query.isEmpty else { return }
        let cappedPage = String(CurrentPage.prefix(12000))
        let currentQuery = "\(cappedPage) \(query)"
        query = ""
        
        Task {
            do {
                if !hasSession {
                    session = LanguageModelSession(instructions: inst)
                    hasSession = true
                }
                
                let options = GenerationOptions(
                    temperature: temp,
                    maximumResponseTokens: maxTokens
                )
                
                let result = try await session!.respond(
                    to: currentQuery,
                    options: options
                ).content
                
                chat.append(ChatItem(query: currentQuery, response: result))
            } catch {
                chat.append(ChatItem(query: currentQuery, response: "Error: \(error.localizedDescription)"))
            }
        }
    }

    private func resetSession() {
        hasSession = false
        chat.removeAll()
        session = nil
    }
}
