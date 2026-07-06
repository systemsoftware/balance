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
    @State var session: LanguageModelSession? = LanguageModelSession()
   
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
    
    @State var hasSession = false
    
    @State var showRename = false
    @State var sessionRename = ""
    
    var contentView: ContentView
    
    init(contentV:ContentView) {
        self.contentView = contentV
        
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
                                    Text(item.query.replacingOccurrences(of: String(CurrentPage.prefix(pageCutoff)), with: ""))
                                        .padding(12)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                
                                // AI Response
                                HStack {
                                    Text(.init(item.response))
                                        .padding(12)
                                        .glassEffect(in: .rect(cornerRadius: 16))
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

    // Bottom Input Bar
    private var inputBar: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Button(action: {
                    if(CurrentPage.count > 0) {
                        CurrentPage = ""
                        return
                    }
                    if let webView = contentView.browserState.webView {
                        webView.getCleanText { cleanedText in
                            if let content = cleanedText {
                                self.CurrentPage = content
                            }
                        }
                    }
                }) {
                    Image(systemName: CurrentPage.count == 0 ? "doc.text" : "doc.text.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CurrentPage.count == 0 ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
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
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
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
        guard !query.isEmpty else { return }
        
        if sessions[currentSessionIndex].items.isEmpty {
            let titleQuery = query
            let sessionID = sessions[currentSessionIndex].id
            Task {
                let titleSession = LanguageModelSession(instructions: "Summarize this into a short chat title of 2-5 words. Output ONLY the title.")
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
        
        let cappedPage = String(CurrentPage.prefix(12000))
        let currentQuery = "\(cappedPage) \(query)"
        query = ""
        
        let newItem = ChatItem(query: currentQuery, response: "")
        let itemID = newItem.id
        sessions[currentSessionIndex].items.append(newItem)
        let currentSessionIdx = currentSessionIndex
        
        chatStore.items = sessions
        chatStore.save()
        
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
                
                let stream = session!.streamResponse(
                    to: currentQuery,
                    options: options
                )
                
                for try await snapshot in stream {
                    await MainActor.run {
                        if let idx = sessions[currentSessionIdx].items.firstIndex(where: { $0.id == itemID }) {
                            sessions[currentSessionIdx].items[idx].response = snapshot.content
                        }
                    }
                }
                
                await MainActor.run {
                    chatStore.items = sessions
                    chatStore.save()
                }
            } catch {
                await MainActor.run {
                    if let idx = sessions[currentSessionIdx].items.firstIndex(where: { $0.id == itemID }) {
                        sessions[currentSessionIdx].items[idx].response = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func resetSession() {
        hasSession = false
        sessions[currentSessionIndex].items.removeAll()
        session = nil
        chatStore.items = sessions
        chatStore.save()
    }
}
