import SwiftUI
import WebKit
import Foundation
import AppKit
import SwiftData

// MARK: - Layout Constants
enum Layout {
    static let outerPadding: CGFloat = 12
    static let controlPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 20
    static let sidebarIconSize: CGFloat = 20
    static let sidebarIconPadding: CGFloat = 8
    static let sidebarItemSpacing: CGFloat = 4
}

struct SidebarItem: Identifiable, Codable {
    var id = UUID()
    var icon: String
    var url: URL?
    var view: String?
}


let builtInSidebar = [
    SidebarItem(icon: "message", view: "ChatView"),
    SidebarItem(icon: "bookmark", view: "BookmarkView"),
    SidebarItem(icon: "gearshape.fill", view: "SettingsView"),
    SidebarItem(icon:"note.text", view: "NotesView"),
    SidebarItem(icon:"clock.arrow.trianglehead.counterclockwise.rotate.90", view:"HistoryView"),
    SidebarItem(icon:"folder", view:"DownloadsView"),
    SidebarItem(icon:"puzzlepiece.extension", view:"ExtensionsView"),
    SidebarItem(icon:"hand.raised", view:"ContentBlockerView")
]

enum BookmarkBarMode: Int, CaseIterable {
    case hidden = 0
    case newTabOnly = 1
    case always = 2
    
    var name: String {
     switch self {
            case .hidden:
         return "Hidden"
     case .newTabOnly:
         return "New Tab Only"
     case .always:
         return "Always"
        }
    }
}

import AppKit

enum BackgroundType: Int {
    case system = 0
    case light = 1
    case dark = 2
    case matchPage = 3
    case custom = 4
  

 }

private struct ReloadButton: View {
    @ObservedObject var state: BrowserState
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if state.isLoading {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: "arrow.clockwise").padding(10)
                }
            }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .keyboardShortcut("r", modifiers: [.command])
    }
}

private struct TrustIndicator: View {
    let trust: SecTrust?
    @Binding var isPresented: Bool
    var body: some View {
        Group {
            if let trust {
                Button(action: { isPresented.toggle() }) {
                    var error: CFError?
                    if SecTrustEvaluateWithError(trust, &error) {
                        Image(systemName: "lock.fill")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading)
            }
        }
    }
}

private struct AddressField: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var body: some View {
        VStack {
            TextField("Search or enter website name", text: $text)
                .onSubmit(onSubmit)
                .padding(Layout.controlPadding)
                .textFieldStyle(.plain)
        }
    }
}

private struct AutoFillPopover: View {
    @Binding var searchTerm: String
    var body: some View {
        AutoFillView(searchTerm: $searchTerm)
            .frame(width: 500, height: 400)
    }
}

struct ExtensionPopupView: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject private var extensionManager = WebExtensionManager.shared
    @State private var urlInput: String = ""

    @StateObject private var sidebarStore = SidebarStore()
    
    @Environment(\.modelContext) private var modelContext

    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    private var sidebarWidth: Int = 300
    
    @AppStorage("userAgent", store:Config.sharedDefaults)
    private var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    
    @AppStorage("homepage", store: Config.sharedDefaults)
    private var homepage: String = "https://www.google.com"
    
    // 0: hidden, 1: only new tab, 2: always
    @AppStorage("bookmarkBar", store: Config.sharedDefaults)
    private var bookmarkBar: Int = 0
    
    @AppStorage("backgroundType", store:Config.sharedDefaults)
    private var backgroundType: Int = 0

    @State private var sidebarURL: URL?
    
    @State private var showInspector = false
    
    @StateObject var browserState = BrowserState()
    
    @StateObject var splitState = BrowserState()
    
    @State private var location: URL?

    @State private var showingSidebarAddAlert = false
    @State private var userInput = ""
    
    @StateObject private var bookmarkStore = BookmarkStore()
    
    @State private var sidebarPage = WebPage()
    
    @AppStorage("recordHistory", store:Config.sharedDefaults)
    private var recordHistory = true
    
    var initialURLString: String?
    
   @State private var splitURL: String = ""
    
    @State private var showFindNavigator = false
    @State private var showTrustInfo = false

    @Namespace private var backforwardNamespace
    @Namespace private var sidebarNamespace
    @Namespace private var bookmarkBarNamespace
    
    var shouldShowBookmarks: Bool {
        guard !bookmarkStore.items.isEmpty else { return false }

        guard let mode = BookmarkBarMode(rawValue: bookmarkBar) else {
            return false
        }

        switch mode {
        case .hidden:
            return false

        case .always:
            return true

        case .newTabOnly:
            return location == URL(string: homepage != "default-home" ? homepage : "")
        }
    }
    
    var priv: Bool = false
    
    init(initialURL: URL? = nil, pvt: Bool = false) {
        if(initialURL != nil) { initialURLString = initialURL?.absoluteString } else { print("nil initial url") }
        priv = pvt
    }
    
    @State var showSuggestions = false
    @State var showCommands = false
    @State var showTabSearch = false
    @State var showServerTrust = false
    @State private var currentActivity: NSUserActivity?
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Address Bar
            HStack(spacing: 8) {
                if location != nil {
                    GlassEffectContainer {
                        HStack(spacing: 0) {
                            if(browserState.canGoBack){
                                Button(action: {
                                    browserState.webView?.goBack()
                                }) {
                                    Image(systemName: "chevron.backward")
                                        .padding(Layout.controlPadding)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.interactive())
                                .glassEffectUnion(id: "backforward", namespace: backforwardNamespace)
                                .keyboardShortcut(.leftArrow, modifiers: .command)
                            }
                            
                            if(browserState.canGoForward) {
                                Button(action: {
                                    Task {
                                        browserState.webView?.goForward()
                                    }
                                }) {
                                    Image(systemName: "chevron.forward")
                                        .padding(Layout.controlPadding)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.interactive())
                                .glassEffectUnion(id: "backforward", namespace: backforwardNamespace)
                                .keyboardShortcut(.rightArrow, modifiers: .command)
                            }
                        }
                    }
                }
                
                if priv {
                    Image(systemName:"eye.slash.fill")
                }

                if location != nil {
                    if location?.absoluteString.starts(with: "http") == true {
                        ShareLink(item: location!) {
                            Image(systemName: "square.and.arrow.up")
                                .padding(Layout.controlPadding)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                        
                    }
                    ReloadButton(state: browserState) {
                        browserState.webView?.reload()
                    }
                }
                
                HStack{
                    if location?.absoluteString.starts(with: "http") == true {
                        TrustIndicator(trust: browserState.webView?.serverTrust, isPresented: $showTrustInfo)
                            .popover(isPresented: $showTrustInfo) {
                                if let trust = browserState.webView?.serverTrust {
                                    ServerTrustView(trust: trust)
                                }
                            }
                    }
                    
                    AddressField(text: $urlInput, onSubmit: submitURL)
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                .popover(isPresented: $showSuggestions) {
                    AutoFillPopover(searchTerm: $urlInput)
                }
                
                .sheet(isPresented: $showCommands) {
                    CommandsView()
                    Button("Close") {
                        showCommands = false
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                
                .sheet(isPresented: $showTabSearch) {
                    TabSearchView()
                    Button("Close") {
                        showTabSearch = false
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }

                if(showFindNavigator) {
                    FindBarView(state:browserState)
                }
                
                Button("") {
                    showSuggestions.toggle()
                }
                .buttonStyle(.plain)
                .keyboardShortcut("s", modifiers: [.command])
            
                HStack(spacing: 12) {
                    /*
                    ForEach(extensionManager.contexts, id: \.self) { context in
                        Button(action: {
                            context.performAction(for: nil)
                        }) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 14))
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .popover(isPresented: Binding(
                            get: { extensionManager.showPopup && extensionManager.popupContext === context },
                            set: { if !$0 { extensionManager.showPopup = false } }
                        )) {
                            if let wv = extensionManager.popupWebView {
                                ExtensionPopupView(webView: wv)
                                    .frame(width: 320, height: 400)
                            }
                        }
             
                    }
                     */

                    Button(action: submitURL) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .padding(Layout.controlPadding)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    
                    Button() {
                        showSuggestions.toggle()
                    } label: {
                        Image(systemName: "keyboard.onehanded.right")
                            .font(.title2)
                            .padding(Layout.controlPadding)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .keyboardShortcut("s", modifiers: [.command, .shift])

                    Menu {
                        
                        
                        Button("Commands") {
                                  showCommands = true
                              }
                              .keyboardShortcut("k", modifiers: [.command])
                        
                        Divider()
                      
                        if let url = location {
                            
                            
                            Button(showFindNavigator ? "Hide Find In Page" : "Find In Page") {
                                showFindNavigator = !showFindNavigator
                            }
                            .keyboardShortcut("f", modifiers: .command)
                            Divider()
                            
                            Button("Search Tabs") {
                                      showTabSearch = true
                                  }
                            .keyboardShortcut("s", modifiers: [.command, .option])
                            
                            Divider()
                            
                            Button() {
                                browserState.toggleMute()
                            } label: {
                                browserState.isAudioMuted ? Label("Unmute Tab", systemImage:"speaker.slash") : Label("Mute Tab", systemImage:"speaker")
                            }
                            .keyboardShortcut("m", modifiers: [.command, .shift])
                            
                            Divider()
                            
                                                            Button("Duplicate Tab", systemImage: "plus.square.on.square") {
                                                                createNewTab(with: url)
                                                            }
                                                            Button("Duplicate in New Window", systemImage: "macwindow.badge.plus") {
                                                                createNewWindow(with: url)
                                                            }
                                                            
                                                            Divider()
                                                            
                                                            Button("Copy Page URL", systemImage: "doc.on.doc") {
                                                                NSPasteboard.general.clearContents()
                                                                NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                                            }
                                                            .keyboardShortcut("c", modifiers: [.command, .control])
                            
                            Divider()
                            
                            Menu() {
                                if(splitURL.isEmpty) {
                                    Button() {
                                        let alert = NSAlert()
                                        alert.informativeText = "Enter split view URL:"
                                        alert.addButton(withTitle: "Go")
                                        alert.addButton(withTitle: "Cancel")
                                        
                                        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                                        input.placeholderString = "https://example.com"
                                        alert.accessoryView = input
                                        alert.window.initialFirstResponder = input
                                        
                                        if alert.runModal() == .alertFirstButtonReturn {
                                            
                                            splitURL = input.stringValue
                                            
                                        }
                                    } label: {
                                        Label("Open", systemImage: "plus")
                                    }
                                } else {
                                    
                                    Button() {
                                        createNewTab(with:URL(string:splitURL))
                                    } label: {
                                        Label("Copy to New Tab", systemImage: "plus.square.on.square")
                                    }
                                    
                                    Divider()
                                    
                                    Button() {
                                        splitURL = ""

                                        let alert = NSAlert()
                                        alert.informativeText = "Enter split view URL:"
                                        alert.addButton(withTitle: "Go")
                                        alert.addButton(withTitle: "Cancel")
                                        
                                        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                                        input.placeholderString = "https://example.com"
                                        alert.accessoryView = input
                                        alert.window.initialFirstResponder = input
                                        
                                        if alert.runModal() == .alertFirstButtonReturn {
                                            splitURL = input.stringValue
                                            
                                        }
                                        
                                    } label: {
                                        Label("Change", systemImage: "link.badge.plus")
                                    }
                                    
                                    Divider()
                                    
                                    Button() {
                                        splitState.toggleMute()
                                    } label: {
                                        splitState.isAudioMuted ? Label("Unmute", systemImage:"speaker.slash") : Label("Mute", systemImage:"speaker")
                                    }
                                    Divider()
                                    
                                    Button() {
                                        splitURL = ""
                                    } label: {
                                        Label("Close", systemImage: "xmark")
                                    }
                                }
                            } label: {
                                Label("Split View", systemImage: "rectangle.split.2x1")
                            }
                            
                            
                            Divider()

                            
                                                            Button("Add to Bookmarks", systemImage: "star") {
                                                                bookmarkStore.add(Bookmark(
                                                                    title: url.host() ?? "Unnamed",
                                                                    url: url.absoluteString
                                                                ))
                                                            }
                                                            .keyboardShortcut("b", modifiers: [.command, .shift])
                            
                            
                            Button("Add to Sidebar", systemImage: "sidebar.left") {
                                sidebarStore.add(SidebarItem(
                                    icon: "https://www.google.com/s2/favicons?domain=\(location?.host() ?? "")",
                                    url: location
                                ))
                            }

                            Divider()
                            
                            Button("Print Page", systemImage: "printer") {
                                printCurrentPage()
                            }
                            .keyboardShortcut("p", modifiers: [.command])
                            
                            Divider()
                            
                            Button("Dev Tools", systemImage: "chevron.left.forwardslash.chevron.right") {
                                let inspector = browserState.webView?.value(forKey: "inspector") as? NSObject
                                inspector?.perform(NSSelectorFromString("show"))
                            }
                            .keyboardShortcut("i", modifiers: [.command, .option])
                            
                                                        }
                            
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                
                
            }
            .padding(.horizontal, Layout.outerPadding)
            .padding(.vertical, 8) 
            .frame(maxWidth: .infinity)
            
            if(shouldShowBookmarks) {
                HStack {
                    ForEach(bookmarkStore.items) { mark in
                        Button(mark.title) {
                                createNewTab(with:URL(string:mark.url))
                            }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove \(mark.title) Bookmark") {
                                bookmarkStore.remove(id: mark.id)
                            }
                    }
                }
                }
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "bookmarkBar", namespace: bookmarkBarNamespace)
            }

            // MARK: - Web Content + Sidebar
            HStack(spacing: 0) {
                // MARK: - Web Content Area
                ZStack {
                    if (location != nil) {
                        HStack(spacing: 8) {
                            BrowserWebView(request:URLRequest(url:URL(string:homepage)!), state: browserState, priv:priv)
                                .roundedBorderStyleNoFrame()
                                .transition(.opacity)
                                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                                .onChange(of: browserState.url) { oldValue, newValue in
                                    handleURLChange(from: oldValue, to: newValue)
                                }
                                // 2. Keep userActivity lightweight by calling a separate function
                                .userActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                                    configureUserActivity(userActivity)
                                }
                            
                            if !splitURL.isEmpty {
                                BrowserWebView(request:URLRequest(url:URL(string:splitURL)!), state: splitState, priv:priv)
                                    .roundedBorderStyleNoFrame()
                                    .transition(.opacity)
                                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                            }
                        }
                    } else {
                       BrowserHomepage()
                            .transition(.opacity)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                            .task {
                                browserState.title = "Balance"
                            }

                    }
                }
                .padding(Layout.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)


                // MARK: - Sidebar

                    HStack(spacing: 8) {
                        if let sidebarURL {
                            if sidebarURL.absoluteString.contains(".view") {

                                switch sidebarURL.absoluteString {
                                case let str where str.contains("Chat"):
                                    ChatView(contentV: self)
                                        .roundedBorderStyle()

                                case let str where str.contains("Bookmark"):
                                    BookmarksView()
                                        .roundedBorderStyle()

                                case let str where str.contains("Settings"):
                                    SettingsView()
                                        .roundedBorderStyle()

                                case let str where str.contains("Note"):
                                    NoteView()
                                        .roundedBorderStyle()

                                case let str where str.contains("History"):
                                    HistoryView()
                                        .roundedBorderStyle()
                                    
                                case let str where str.contains("Download"):
                                    DownloadsView()
                                        .roundedBorderStyle()

                                case let str where str.contains("Extension"):
                                    ExtensionsView()
                                        .roundedBorderStyle()
                                        
                                case let str where str.contains("ContentBlocker"):
                                    ContentBlockerView()
                                        .roundedBorderStyle()
                                        
                                default:
                                    EmptyView()
                                }
                                
                            } else {
                                WebView(sidebarPage)
                                    .frame(width: CGFloat(sidebarWidth))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                            }
                        }

                        VStack(spacing: Layout.sidebarItemSpacing) {
                            GlassEffectContainer {
                                ForEach(sidebarStore.items) { item in
                                    Button(action: {
                                        let targetURL = item.url ?? URL(string: "\(item.view!).view")
                                        if sidebarURL == targetURL {
                                            sidebarURL = nil
                                        } else {
                                            sidebarURL = targetURL
                                        }
                                    }) {
                                        if item.icon.starts(with: "https") {
                                            AsyncImage(url: URL(string: item.icon))
                                                .frame(width: Layout.sidebarIconSize, height: Layout.sidebarIconSize)
                                                .padding(Layout.sidebarIconPadding)
                                        } else {
                                            Image(systemName: item.icon)
                                                .resizable()
                                                .frame(width: Layout.sidebarIconSize, height: Layout.sidebarIconSize)
                                                .padding(Layout.sidebarIconPadding)
                                        }
                                    }
                                    .glassEffect(.regular.interactive())
                                    .padding(1)
                                    .glassEffectUnion(id: "sidebar", namespace: sidebarNamespace)
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if sidebarStore.count() > 1 {
                                            Button("Remove", role: .destructive) {
                                                sidebarStore.remove(id: item.id)
                                            }
                                            Divider()
                                        }
                                        Button("Add remote page") {
                                            showingSidebarAddAlert = true
                                        }
                                        Menu("Add built-in") {
                                            ForEach(builtInSidebar) { builtIn in
                                                let title = builtIn.view?.replacingOccurrences(of: "View", with: "") ?? builtIn.icon
                                                Button(title, action: {
                                                    guard let view = builtIn.view else { return }
                                                    sidebarStore.add(SidebarItem(icon: builtIn.icon, view: view))
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .alert("Enter URL", isPresented: $showingSidebarAddAlert) {
                            TextField("URL", text: $userInput)
                            Button("OK") {
                                sidebarStore.add(SidebarItem(
                                    icon: "https://www.google.com/s2/favicons?domain=\(userInput)",
                                    url: URL(string: userInput)!
                                ))
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, Layout.outerPadding)
                    }
                    .padding(.trailing, Layout.outerPadding)
                    .padding(.vertical, Layout.outerPadding)
                }
        }.onAppear {
            if let initialURLString {
                print("has initialURLString: \(initialURLString)")
                location = URL(string:initialURLString)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("Attempting to load homepage: \(homepage)")
                
                if homepage == "default-home" {
                    browserState.title = "Home"
                } else if let url = URL(string: homepage) {
                    location = url
                } else {
                    print("Homepage URL was invalid: \(homepage)")
                }
            }
        }
        .navigationTitle(browserState.title)
        .onChange(of: sidebarURL) {
            sidebarPage.customUserAgent = userAgent
            if(sidebarURL != nil) { sidebarPage.load(sidebarURL!) }
        }.onChange(of: location) { _, newValue in
            guard let url = newValue else { return }
            if let web = browserState.webView {
                web.customUserAgent = userAgent
                web.load(URLRequest(url: url))
            } else{
                print("no webview")
            }
        } .onAppear {
            sidebarPage.customUserAgent = userAgent
        }
        .onReceive(NotificationCenter.default.publisher(for: .openURLInNewTab)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                location = url
            }
        }

        
        
    }

    // MARK: - Helper Methods
    private func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
     //   guard !trimmed.isEmpty else { return }

        let url: URL?
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            url = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)")
        } else if(trimmed == "default-home" || trimmed.count == 0) {
            url = nil
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "https://www.google.com/search?q=\(encoded)")
        }

        location = url
    }
    
   
    private func printCurrentPage() {
        guard let webView = browserState.webView else { return }

        let printInfo = NSPrintInfo()

        let operation = webView.printOperation(with: printInfo)

        // Force layout before printing
        operation.view?.frame = webView.bounds
        operation.view?.layoutSubtreeIfNeeded()

        operation.showsPrintPanel = true
        operation.showsProgressPanel = true

        operation.run()
    }
    

    private func configureUserActivity(_ userActivity: NSUserActivity) {
        userActivity.webpageURL = browserState.url
        self.currentActivity = userActivity
    }

    private func handleURLChange(from oldValue: URL?, to newValue: URL?) {
        guard let newURL = newValue else { return }
        
        urlInput = newURL.absoluteString
        
        if priv == true { return }
        
        if let activity = currentActivity {
            activity.webpageURL = newURL
            activity.needsSave = true
        }
        
        if recordHistory == true && newURL.absoluteString != homepage {
            let historyTitle = browserState.title.isEmpty ? (newURL.host() ?? "No Title") : browserState.title
            let historyURL = newURL.absoluteString
            
            HistoryManager.addToHistory(
                title: historyTitle,
                url: historyURL,
                context: modelContext
            )
        }
    }

    
}

