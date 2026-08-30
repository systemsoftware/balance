import SwiftUI
import FoundationModels
import WebKit

private let model = SystemLanguageModel.default

struct ChatItem: Identifiable, Codable {
    var id = UUID()
    var query: String
    var response: String
}


struct ChatSession: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [ChatItem]
}

struct ChatView: View {
    @AppStorage("instructions", store: Config.sharedDefaults) var inst: String = ""
    @AppStorage("temp", store: Config.sharedDefaults) var temp: Double = 0.7
    @AppStorage("maxTokens", store: Config.sharedDefaults) var maxTokens: Int = 1000
    @AppStorage("pageCutoff", store:Config.sharedDefaults) var pageCutoff: Int = 12000

    var chatStore = ChatStore()

    @State var sessions: [ChatSession] = [
        ChatSession(title: "Chat 1", items: [])
    ]
    @State var selectedSessionId: ChatSession.ID? = nil
    
    @State private var query: String = ""
    @State private var modelSessions: [ChatSession.ID: LanguageModelSession] = [:]
    @State private var respondingSessionIDs: Set<ChatSession.ID> = []
   
    private var currentSessionIndex: Int {
        if let selectedSessionId,
           let idx = sessions.firstIndex(where: { $0.id == selectedSessionId }) {
            return idx
        }
        return 0
    }

    private var currentChat: Binding<[ChatItem]> {
        Binding(
            get: { sessions[currentSessionIndex].items },
            set: {
            
                sessions[currentSessionIndex].items = $0
                chatStore.save()
                
            }
        )
    }
    
    @State var showRename = false
    @State var sessionRename = ""
    
    @ObservedObject var browserState: BrowserState
    
    init(browserState: BrowserState) {
        self.browserState = browserState
        
        let store = ChatStore()
        self.chatStore = store
        
        let loadedItems = store.items
        let initialSessions = loadedItems.isEmpty ? [ChatSession(title: "New Chat", items: [])] : loadedItems
        _sessions = State(initialValue: initialSessions)
        _selectedSessionId = State(initialValue: initialSessions.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            chatTabs
                .padding(.vertical, 6)
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
            
            inputBar
        }
        .background(Color.black.opacity(0.1))
        .onChange(of: browserState.url) { _, _ in
            // Page context is only valid for the document it was extracted from.
            // Invalidate any late WebKit callback from the previous navigation.
            pageExtractionID = nil
            isAddingCurrentPage = false
            CurrentPage = ""
        }
    }
    
    private var chatTabs: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sessions) { session in
                        Text(session.title)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(session.id == sessions[currentSessionIndex].id ? Color.white.opacity(0.15) : Color.clear)
                            .clipShape(Capsule())
                            .onTapGesture {
                                selectedSessionId = session.id
                            }
                            .contextMenu {
                                Button("Delete") {
                                    if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                                        sessions.remove(at: idx)
                                        if sessions.isEmpty {
                                            sessions.append(ChatSession(title: "New Chat", items: []))
                                        }
                                        selectedSessionId = sessions.first?.id
                                        chatStore.items = sessions
                                        chatStore.save()
                                        modelSessions.removeValue(forKey: session.id)
                                        respondingSessionIDs.remove(session.id)
                                    }
                                }
                                Divider()
                                Button("Rename") {
                                    showRename = true
                                }
                            }
                            .sheet(isPresented: $showRename) {
                                VStack(alignment: .leading, spacing: 14) {

                                    Text("Rename Session")
                                        .font(.headline)

                                    TextField("Session name", text: $sessionRename)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 320)

                                    HStack {
                                        Spacer()

                                        Button("Cancel") {
                                            showRename = false
                                        }
                                        .keyboardShortcut(.escape)

                                        Button("Rename") {
                                            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                                                sessions[idx].title = sessionRename
                                                chatStore.items = sessions
                                                chatStore.save()
                                            }
                                            showRename = false
                                        }
                                        .keyboardShortcut(.return)
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .padding(20)
                                .frame(width: 380)
                            }
                    }
                    Button(action: {
                        let new = ChatSession(title: "Chat \(sessions.count + 1)", items: [])
                        sessions.append(new)
                        selectedSessionId = new.id
                        chatStore.items = sessions
                        chatStore.save()
                        resetSession()
                    }) {
                        Image(systemName: "plus")
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            
            Button(action: resetSession) {
                Image(systemName: "arrow.counterclockwise")
                    .padding(8)
            }
            .buttonStyle(.plain)
            .padding(.trailing)
            .help("Reset Session")
        }
    }

    // Scrollable Chat History
    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !sessions[currentSessionIndex].items.isEmpty {
                        ForEach(sessions[currentSessionIndex].items) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                // User Query
                                HStack {
                                    Spacer()
                                    Text(item.query.replacingOccurrences(of: String(CurrentPage.prefix(pageCutoff)), with: "").trimmingCharacters(in: .whitespaces))
                                        .padding(12)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .textSelection(.enabled)
                                }
                                
                                // AI Response
                                HStack {
                                    Text(.init(item.response))
                                        .padding(12)
                                        .glassEffect(in: .rect(cornerRadius: 16))
                                        .textSelection(.enabled)
                                    Spacer()
                                }
                            }
                            .id(item.id)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("How can I help you today?")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .onChange(of: sessions[currentSessionIndex].items.count) { _, _ in
                if let lastItem = sessions[currentSessionIndex].items.last {
                    withAnimation {
                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @State var CurrentPage: String = ""
    @State private var isAddingCurrentPage = false
    @State private var pageExtractionID: UUID?

    // Bottom Input Bar
    private var inputBar: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Button(action: {
                    if(CurrentPage.count > 0) {
                        CurrentPage = ""
                        return
                    }
                    guard !isAddingCurrentPage,
                          let webView = browserState.webView else { return }

                    isAddingCurrentPage = true
                    let extractionID = UUID()
                    let sourceURL = webView.url
                    pageExtractionID = extractionID
                    let characterLimit = min(max(pageCutoff, 1), 50_000)
                    webView.getTextForAI(maxCharacters: characterLimit) { [weak webView] cleanedText in
                        DispatchQueue.main.async {
                            guard pageExtractionID == extractionID,
                                  let webView,
                                  webView === browserState.webView,
                                  webView.url == sourceURL else { return }
                            if let content = cleanedText {
                                self.CurrentPage = content
                            }
                            self.pageExtractionID = nil
                            self.isAddingCurrentPage = false
                        }
                    }
                }) {
                    if isAddingCurrentPage {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: CurrentPage.count == 0 ? "doc.text" : "doc.text.fill")
                            .font(.system(size: 20))
                            .foregroundColor(CurrentPage.count == 0 ? .secondary : .accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAddingCurrentPage)
                .help(CurrentPage.count == 0 ? "Add Current Page" : "Remove Current Page")
                
                TextField("Ask anything...", text: $query, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(query.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || respondingSessionIDs.contains(sessions[currentSessionIndex].id))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 24))
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
        let submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedQuery.isEmpty else { return }
        let currentSessionID = sessions[currentSessionIndex].id
        guard !respondingSessionIDs.contains(currentSessionID) else { return }
        
        let characterLimit = min(max(pageCutoff, 1), 50_000)
        let cappedPage = String(CurrentPage.prefix(characterLimit))
        let currentQuery = cappedPage.isEmpty
            ? submittedQuery
            : "Page context:\n\(cappedPage)\n\nUser question:\n\(submittedQuery)"
        
        if sessions[currentSessionIndex].items.isEmpty {
            let titleQuery = currentQuery
            let sessionID = sessions[currentSessionIndex].id
            Task {
                let titleSession = LanguageModelSession(instructions: "Generate a short chat title of 2-5 words based on this prompt. Output ONLY the title, no conversational text.")
                if let title = try? await titleSession.respond(to: titleQuery).content {
                    await MainActor.run {
                        if let idx = sessions.firstIndex(where: { $0.id == sessionID }) {
                            sessions[idx].title = title.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            chatStore.items = sessions
                            chatStore.save()
                        }
                    }
                }
            }
        }
        
        query = ""
        
        // Page context belongs in the model prompt, not the rendered or persisted
        // chat item. Keeping it here caused large pages to be copied repeatedly.
        let newItem = ChatItem(query: submittedQuery, response: "")
        let itemID = newItem.id
        sessions[currentSessionIndex].items.append(newItem)
        respondingSessionIDs.insert(currentSessionID)
        
        chatStore.items = sessions
        chatStore.save()
        
        Task {
            defer {
                Task { @MainActor in
                    respondingSessionIDs.remove(currentSessionID)
                }
            }
            do {
                let activeModelSession: LanguageModelSession
                if let existing = modelSessions[currentSessionID] {
                    activeModelSession = existing
                } else {
                    let created = LanguageModelSession(instructions: inst)
                    modelSessions[currentSessionID] = created
                    activeModelSession = created
                }
                
                let options = GenerationOptions(
                    temperature: temp,
                    maximumResponseTokens: maxTokens
                )
                
                let stream = activeModelSession.streamResponse(
                    to: currentQuery,
                    options: options
                )
                
                for try await snapshot in stream {
                    await MainActor.run {
                        if let sessionIndex = sessions.firstIndex(where: { $0.id == currentSessionID }),
                           let itemIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == itemID }) {
                            sessions[sessionIndex].items[itemIndex].response = snapshot.content
                        }
                    }
                }
                
                await MainActor.run {
                    chatStore.items = sessions
                    chatStore.save()
                }
            } catch {
                await MainActor.run {
                    if let sessionIndex = sessions.firstIndex(where: { $0.id == currentSessionID }),
                       let itemIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == itemID }) {
                        sessions[sessionIndex].items[itemIndex].response = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func resetSession() {
        let sessionID = sessions[currentSessionIndex].id
        sessions[currentSessionIndex].items.removeAll()
        modelSessions.removeValue(forKey: sessionID)
        respondingSessionIDs.remove(sessionID)
        chatStore.items = sessions
        chatStore.save()
    }
}
