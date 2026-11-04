import SwiftUI
import FoundationModels
import WebKit
import PhotosUI
internal import UniformTypeIdentifiers
import ImageIO

private let model = SystemLanguageModel.default

struct ChatItem: Identifiable, Codable {
    var id = UUID()
    var query: String
    var response: String
    var imageName: String? = nil
}


struct ChatSession: Identifiable, Codable {
    var id = UUID()
    var title: String
    var items: [ChatItem]
}


@available(iOS 27.0, macOS 27.0, *)
struct ChatView: View {
    @AppStorage("instructions", store: Config.sharedDefaults) var inst: String = ""
    @AppStorage("temp", store: Config.sharedDefaults) var temp: Double = 0.7
    @AppStorage("maxTokens", store: Config.sharedDefaults) var maxTokens: Int = 1000
    @AppStorage("pageCutoff", store: Config.sharedDefaults) var pageCutoff: Int = 12000

    @ObservedObject var browserState: BrowserState
    @State private var chatStore: ChatStore
    @State private var sessions: [ChatSession]
    @State private var selectedSessionID: UUID
    @State private var modelSessions: [UUID: LanguageModelSession] = [:]
    @State private var respondingIDs: Set<UUID> = []
    @State private var query = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var imageName: String?
    @State private var isImporting = false
    @State private var pageText = ""
    @State private var pageTitle = ""
    @State private var isLoadingPage = false
    @State private var pageRequestID: UUID?
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var errorMessage: String?

    init(browserState: BrowserState) {
        self.browserState = browserState
        let store = ChatStore()
        let saved = store.items.isEmpty ? [ChatSession(title: "New Chat", items: [])] : store.items
        _chatStore = State(initialValue: store)
        _sessions = State(initialValue: saved)
        _selectedSessionID = State(initialValue: saved[0].id)
    }

    private var selectedIndex: Int {
        sessions.firstIndex { $0.id == selectedSessionID } ?? 0
    }

    private var canSend: Bool {
        (!query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil)
            && !respondingIDs.contains(selectedSessionID)
            && model.availability == .available
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            conversation
            composer
        }
        .background(Color.black.opacity(0.04))
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do { try setImage(Data(contentsOf: url), name: url.lastPathComponent) }
                catch { errorMessage = error.localizedDescription }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            Task {
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { return }
                    try setImage(data, name: "Photo")
                } catch { errorMessage = error.localizedDescription }
                selectedPhoto = nil
            }
        }
        .onChange(of: browserState.url) { _, _ in
            pageRequestID = nil
            isLoadingPage = false
            pageText = ""
            pageTitle = ""
        }
        .alert("Rename Chat", isPresented: Binding(
            get: { renamingID != nil },
            set: { if !$0 { renamingID = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Save") { renameChat() }
            Button("Cancel", role: .cancel) { renamingID = nil }
        }
        .alert("Chat Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sessions) { session in
                        Button(session.title) { selectedSessionID = session.id }
                            .buttonStyle(.plain)
                            .font(.caption.weight(session.id == selectedSessionID ? .semibold : .regular))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .glassEffect(session.id == selectedSessionID ? .clear : .regular, in: .capsule)
                            .background(session.id == selectedSessionID ? Color.accentColor.opacity(0.15) : Color.clear, in: .capsule)
                            .contextMenu {
                                Button("Rename") {
                                    renameText = session.title
                                    renamingID = session.id
                                }
                                Button("Delete", role: .destructive) { deleteChat(session.id) }
                            }
                    }
                }
                .padding(.horizontal, 10)
            }
            Button { newChat() } label: { Image(systemName: "plus") }
                .help("New chat")
                .buttonStyle(.plain)
                .accessibilityLabel("New chat")
                .padding(.trailing, 10)
        }
        .padding(.vertical, 8)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if sessions[selectedIndex].items.isEmpty {
                        ContentUnavailableView("Ask anything", systemImage: "sparkles",
                                               description: Text("Ask about this page or add an image."))
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                    ForEach(sessions[selectedIndex].items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer(minLength: 40)
                                VStack(alignment: .trailing, spacing: 6) {
                                    if let imageName = item.imageName {
                                        Label(imageName, systemImage: "photo")
                                            .font(.caption)
                                    }
                                    if !item.query.isEmpty { Text(item.query).textSelection(.enabled) }
                                }
                                .padding(12)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(.white)
                            }
                            HStack(alignment: .top) {
                                if item.response.isEmpty {
                                    ProgressView().controlSize(.small).padding(12)
                                } else {
                                    Text(.init(item.response))
                                        .textSelection(.enabled)
                                        .padding(12)
                                        .glassEffect(in: .rect(cornerRadius: 18))
                                }
                                Spacer(minLength: 40)
                            }
                        }
                        .id(item.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: sessions[selectedIndex].items.last?.response) { _, _ in
                if let id = sessions[selectedIndex].items.last?.id { proxy.scrollTo(id, anchor: .bottom) }
            }
            .onChange(of: selectedSessionID) { _, _ in
                if let id = sessions[selectedIndex].items.last?.id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !pageText.isEmpty || imageData != nil {
                HStack(spacing: 8) {
                    if !pageText.isEmpty {
                        attachmentChip(pageTitle.isEmpty ? "Current page" : pageTitle, icon: "doc.text") {
                            pageText = ""; pageTitle = ""
                        }
                    }
                    if let imageName {
                        attachmentChip(imageName, icon: "photo") {
                            imageData = nil; self.imageName = nil
                        }
                    }
                }
            }
            TextField("Ask anything…", text: $query, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .onSubmit(sendMessage)
            HStack(spacing: 12) {
                Button { togglePage() } label: {
                    if isLoadingPage { ProgressView().controlSize(.small) }
                    else { Image(systemName: pageText.isEmpty ? "doc.text" : "doc.text.fill") }
                }
                .disabled(isLoadingPage || browserState.webView == nil)
                .help(pageText.isEmpty ? "Add current page" : "Remove current page")
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                }
                .help("Add photo")
                Button { isImporting = true } label: { Image(systemName: "paperclip") }
                    .help("Add image file")
                Spacer()
                if model.availability != .available {
                    Text(modelStatus).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(!canSend)
                .help("Send message")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 20))
        .padding(10)
    }

    private func attachmentChip(_ title: String, icon: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Label(title, systemImage: icon).lineLimit(1)
            Button(action: remove) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(title)")
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary, in: Capsule())
    }

    private var modelStatus: String {
        switch model.availability {
        case .available: return ""
        case .unavailable(.deviceNotEligible): return "Apple Intelligence unavailable on this device"
        case .unavailable(.appleIntelligenceNotEnabled): return "Enable Apple Intelligence in Settings"
        case .unavailable(.modelNotReady): return "Model is preparing"
        case .unavailable: return "Model unavailable"
        }
    }

    private func setImage(_ data: Data, name: String) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        imageData = data
        imageName = name
    }

    private func togglePage() {
        if !pageText.isEmpty { pageText = ""; pageTitle = ""; return }
        guard let webView = browserState.webView else { return }
        let requestID = UUID()
        let sourceURL = webView.url
        pageRequestID = requestID
        isLoadingPage = true
        webView.getTextForAI(maxCharacters: min(max(pageCutoff, 1), 50_000)) { [weak webView] text in
            DispatchQueue.main.async {
                guard pageRequestID == requestID else { return }
                pageRequestID = nil
                isLoadingPage = false
                guard let webView, webView === browserState.webView, webView.url == sourceURL else { return }
                pageText = text ?? ""
                pageTitle = webView.title ?? sourceURL?.host ?? "Current page"
            }
        }
    }

    private func sendMessage() {
        guard canSend else { return }
        let message = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = imageData
        let name = imageName
        let page = String(pageText.prefix(min(max(pageCutoff, 1), 50_000)))
        let title = pageTitle
        let sessionID = selectedSessionID
        let item = ChatItem(query: message, response: "", imageName: name)
        sessions[selectedIndex].items.append(item)
        respondingIDs.insert(sessionID)
        query = ""
        imageData = nil
        imageName = nil
        pageText = ""
        pageTitle = ""
        persist()

        Task {
            defer { respondingIDs.remove(sessionID) }
            do {
                let session: LanguageModelSession
                var previousConversation = ""
                if let existing = modelSessions[sessionID] { session = existing }
                else {
                    session = LanguageModelSession(instructions: inst)
                    modelSessions[sessionID] = session
                    if let index = sessions.firstIndex(where: { $0.id == sessionID }) {
                        let pastItems = sessions[index].items.dropLast()
                        previousConversation = String(pastItems.suffix(12).map {
                            "User: \($0.query)\nAssistant: \($0.response)"
                        }.joined(separator: "\n\n").suffix(10_000))
                    }
                }
                let request = message.isEmpty ? "Describe this image." : message
                let pageContext = page.isEmpty ? "" : "Page title: \(title)\nPage context:\n\(page)\n\n"
                let historyContext = previousConversation.isEmpty ? "" : "Conversation so far:\n\(previousConversation)\n\n"
                let text = "\(historyContext)\(pageContext)User request:\n\(request)"
                let prompt: Prompt
                if let data, let source = CGImageSourceCreateWithData(data as CFData, nil),
                   let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    prompt = Prompt { text; Attachment(image) }
                } else {
                    prompt = Prompt { text }
                }
                let stream = session.streamResponse(to: prompt, options: GenerationOptions(
                    temperature: temp, maximumResponseTokens: maxTokens))
                for try await snapshot in stream {
                    guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
                          let itemIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == item.id }) else { break }
                    sessions[sessionIndex].items[itemIndex].response = snapshot.content
                }
                if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
                   sessions[sessionIndex].items.count == 1,
                   sessions[sessionIndex].title == "New Chat" {
                    sessions[sessionIndex].title = String((message.isEmpty ? name ?? "Image" : message).prefix(36))
                }
                persist()
            } catch {
                if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
                   let itemIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == item.id }) {
                    sessions[sessionIndex].items[itemIndex].response = "Error: \(error.localizedDescription)"
                }
                persist()
            }
        }
    }

    private func newChat() {
        let new = ChatSession(title: "New Chat", items: [])
        sessions.append(new)
        selectedSessionID = new.id
        persist()
    }

    private func deleteChat(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        modelSessions.removeValue(forKey: id)
        if sessions.isEmpty { sessions = [ChatSession(title: "New Chat", items: [])] }
        if selectedSessionID == id { selectedSessionID = sessions[0].id }
        persist()
    }

    private func renameChat() {
        guard let id = renamingID, let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { sessions[index].title = name; persist() }
        renamingID = nil
    }

    private func persist() {
        chatStore.items = sessions
        chatStore.save()
    }
}

struct ChatViewLegacy: View {
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
