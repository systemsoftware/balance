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
    SidebarItem(icon:"clock.arrow.trianglehead.counterclockwise.rotate.90", view:"HistoryView")
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

struct ContentView: View {
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

    @State private var sidebarURL: URL?
    
    @State private var showInspector = false
    
    @StateObject var browserState = BrowserState()
    
    @State private var location: URL?

    @State private var showingSidebarAddAlert = false
    @State private var userInput = ""
    
    @StateObject private var bookmarkStore = BookmarkStore()
    
    @State private var sidebarPage = WebPage()
    
    @State var privateMode = false
    
    var initialURLString: String?
    
    @State private var showFindNavigator = false

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
            return location == URL(string: homepage != "default-home" ? homepage : Bundle.main.url(forResource: "home", withExtension: "html")!.absoluteString)
        }
    }
    
    init(initialURL: URL? = nil) {
        if(initialURL != nil) { initialURLString = initialURL?.absoluteString } else { print("nil initial url") }
    }
    
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
                            }
                        }
                    }

                    if(location?.absoluteString.starts(with: "http") == true){
                        ShareLink(item: location!) {
                            Image(systemName: "square.and.arrow.up")
                                .padding(Layout.controlPadding)
                        }
                        
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        
                    }
                    Button(action: {
                        browserState.webView?.reload()
                    } ) {
                        if(browserState.isLoading == true){
                            ProgressView()
                                .scaleEffect(0.6)
                            
                        } else{
                            Image(systemName: "arrow.clockwise")
                                .padding(10)
                        }
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                
                HStack{
                    if(location?.absoluteString.starts(with: "http") == true){
                    Button(action: {
                        print("info soon")
                    } ) {
                            if let trust = browserState.webView?.serverTrust {
                            var error: CFError?
                            if SecTrustEvaluateWithError(trust, &error) {
                                Image(systemName: "lock.fill")
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading)
                }
     
                    TextField("Search or enter website name", text: $urlInput)
                        .onSubmit(submitURL)
                        .padding(Layout.controlPadding)
                        .textFieldStyle(.plain)
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))

                if(showFindNavigator) {
                    FindBarView(state:browserState)
                }
                
                HStack(spacing: 12) {
                    Button(action: submitURL) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .padding(Layout.controlPadding)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)

                    Menu {
                        Button(showFindNavigator ? "Hide Find In Page" : "Find In Page") {
                            showFindNavigator = !showFindNavigator
                        }
                        .keyboardShortcut("f", modifiers: .command)
                                                        // 1. LINK ACTIONS
                        
                        Divider()
                        
                        if let url = location {
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

                            
                                                            Button("Add to Bookmarks", systemImage: "star") {
                                                                bookmarkStore.add(Bookmark(
                                                                    title: url.host() ?? "Unnamed",
                                                                    url: url.absoluteString
                                                                ))
                                                            }
                            
                                                        }
                                                
                         
                        
                        Button("Add to Sidebar", systemImage: "sidebar.left") {
                            sidebarStore.add(SidebarItem(
                                icon: "https://www.google.com/s2/favicons?domain=\(location?.host() ?? "")",
                                url: location
                            ))
                        }
                        
                        Divider()
                        
                        Toggle("Private Mode", isOn:$privateMode)
            

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
                        BrowserWebView(request:URLRequest(url:URL(string:homepage)!), state: browserState)
                            .roundedBorderStyleNoFrame()
                            .transition(.opacity)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                            .onChange(of: browserState.url) { oldValue, newValue in
                                if let newURL = newValue {
                                    urlInput = newURL.absoluteString
                                   
                                    
                                    if(privateMode == false) {
                                        HistoryManager.addToHistory(
                                            title: browserState.title.isEmpty ? browserState.url!.host() ?? "No Title" : browserState.title,
                                            url: browserState.url?.absoluteString ?? "https://example.com",
                                            context: modelContext
                                        )
                                    }
                                    
                                }
                            }.onChange(of: browserState.title) { old, new in
                                if let window = NSApp.keyWindow {
                                    window.title = new
                                } else {
                                    print("no key window")
                                }
                            }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            Text("Loading...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(Layout.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)


                // MARK: - Sidebar

                    HStack(spacing: 8) {
                        if let sidebarURL {
                            if sidebarURL.absoluteString.contains(".view") {
                                if sidebarURL.absoluteString.contains("Chat") {
                                    ChatView(contentV: self)
                                        .roundedBorderStyle()
                                } else if sidebarURL.absoluteString.contains("Bookmark") {
                                    BookmarksView()
                                        .roundedBorderStyle()
                                } else if (sidebarURL.absoluteString.contains("Settings")) {
                                    SettingsView()
                                        .roundedBorderStyle()
                                } else if (sidebarURL.absoluteString.contains("Note")) {
                                    NoteView()
                                        .roundedBorderStyle()
                                } else if(sidebarURL.absoluteString.contains("History")) {
                                    HistoryView()
                                        .roundedBorderStyle()
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
                    if let localURL = Bundle.main.url(forResource: "home", withExtension: "html") {
                        location = localURL
                    } else {
                        print("Error: home.html not found in bundle")
                    }
                } else if let url = URL(string: homepage) {
                    location = url
                } else {
                    print("Homepage URL was invalid: \(homepage)")
                }
            }
        }.onChange(of: sidebarURL) {
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
        }

    }

    // MARK: - Helper Methods
    private func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let url: URL?
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            url = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)")
        } else if(trimmed == "homepage" || trimmed == "local-home") {
            url = Bundle.main.url(forResource: "home", withExtension: "html")
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "https://www.google.com/search?q=\(encoded)")
        }

        location = url
    }
}

