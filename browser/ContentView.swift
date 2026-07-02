import SwiftUI
import WebKit
import Foundation
import AppKit
import SwiftData
import FoundationModels

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
    SidebarItem(icon: "bookmark", view: "BookmarksView"),
    SidebarItem(icon: "gearshape.fill", view: "SettingsView"),
    SidebarItem(icon:"note.text", view: "NotesView"),
    SidebarItem(icon:"clock.arrow.trianglehead.counterclockwise.rotate.90", view:"HistoryView"),
    SidebarItem(icon:"folder", view:"DownloadsView"),
    SidebarItem(icon:"puzzlepiece.extension", view:"ExtensionsView"),
    SidebarItem(icon:"hand.raised", view:"ContentBlockerView"),
    SidebarItem(icon:"map", view:"MapView"),
    SidebarItem(icon:"antenna.radiowaves.left.and.right", view:"RSSView")
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
    let url: URL?
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
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
            } else if url?.scheme == "http" {
                Button(action: { isPresented.toggle() }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
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
        List {
            AutoFillView(searchTerm: $searchTerm)
        }
        .listStyle(.inset)
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
    private var homepage: String = "default-home"
    
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
    
    @State private var scanningForEvents = false
    @State private var summarizing = false
    
    @StateObject private var bookmarkStore = BookmarkStore()
    
    @State private var sidebarPage = WebPage()
    
    @AppStorage("recordHistory", store:Config.sharedDefaults)
    private var recordHistory = true
    
    var initialURLString: String?
    
   @State private var splitURL: String = ""
    
    @AppStorage("paletteShowTabs", store:Config.sharedDefaults) var paletteShowTabs: Bool = true
    
    @AppStorage("usePDFKit", store:Config.sharedDefaults) var usePDFKit: Bool = true
    
    @AppStorage("showSidebar", store:Config.sharedDefaults) var showSidebar = true
    
    @State private var showFindNavigator = false
    @State private var showTrustInfo = false
    
    @State private var currentUserActivity: NSUserActivity?
    
    @AppStorage("showExtInToolbar", store:Config.sharedDefaults) var showExtInToolbar = true
    @AppStorage("showAutocompleteInToolbar", store:Config.sharedDefaults) var showAutocompleteInToolbar = true
    @AppStorage("showShareInToolbar", store:Config.sharedDefaults) var showShareInToolbar = true
    @AppStorage("showSearchButtonInToolbar", store:Config.sharedDefaults) var showSearchButtonInToolbar = true
    @AppStorage("showNavInToolbar", store:Config.sharedDefaults) var showNavInToolbar = true
    @AppStorage("showMoreInToolbar", store:Config.sharedDefaults) var showMoreInToolbar = true
    @AppStorage("showAddrBarInToolbar", store:Config.sharedDefaults) var showAddrBarInToolbar = true
    @AppStorage("showReloadInToolbar", store:Config.sharedDefaults) var showReloadInToolbar = true


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
    var bProfile: String = ""
    var bProfileIcon: String? = ""
    var bProfileName: String? = ""
    
    @AppStorage("profiles", store: Config.sharedDefaults)
    private var profilesJSON = "[]"
    
    @AppStorage("defaultProfile", store:Config.sharedDefaults) var defaultProfile = ""
    private var profiles: [Profile] {
        get {
            (try? JSONDecoder().decode([Profile].self,
                                       from: Data(profilesJSON.utf8))) ?? []
        }
        set {
            profilesJSON = String(
                data: try! JSONEncoder().encode(newValue),
                encoding: .utf8
            )!
        }
    }

    var tabID: String
    var restoredState: TabSessionState?

    init(initialURL: URL? = nil, pvt: Bool = false, profile: String = "", profileIcon: String = "", tabID: String = UUID().uuidString, restoredState: TabSessionState? = nil) {
        self.tabID = tabID
        self.restoredState = restoredState
        
        let initURLString = restoredState?.url ?? initialURL?.absoluteString
        if(initURLString != nil) { initialURLString = initURLString } else { print("nil initial url") }
        
        self._location = State(initialValue: initURLString != nil ? URL(string: initURLString!) : nil)
        self._splitURL = State(initialValue: restoredState?.splitURL ?? "")
        self._sidebarURL = State(initialValue: restoredState?.sidebarURL != nil ? URL(string: restoredState!.sidebarURL!) : nil)
        
        priv = restoredState?.isPrivate ?? pvt
        bProfile = restoredState?.profile ?? profile
        bProfileIcon = profileIcon
        
        if bProfile.isEmpty && !defaultProfile.isEmpty {
            bProfile = defaultProfile
            bProfileIcon = profiles.first(where: { $0.id.uuidString == bProfile })?.icon
        }
        
        if !bProfile.isEmpty {
            bProfileName = profiles.first(where: { $0.id.uuidString == bProfile })?.name
        }
        
        let initialBrowserState = BrowserState()
        if let state = restoredState {
            initialBrowserState.restoredScrollX = state.scrollX
            initialBrowserState.restoredScrollY = state.scrollY
        }
        self._browserState = StateObject(wrappedValue: initialBrowserState)
        
        let initialSplitState = BrowserState()
        if let state = restoredState {
            initialSplitState.restoredScrollX = state.splitScrollX
            initialSplitState.restoredScrollY = state.splitScrollY
        }
        self._splitState = StateObject(wrappedValue: initialSplitState)
    }
    
    @State var showSuggestions = false
    @State var showCommands = false
    @State var showTabSearch = false
    @State var showServerTrust = false
    @State private var showReader = false
    @State private var showExtensionsPopover = false
    
    @State var commandSearchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Address Bar
            HStack(spacing: 8) {
                if location != nil && showNavInToolbar {
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
                            
                            if browserState.canGoForward {
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
                
                
                if location != nil {
                    if location?.absoluteString.starts(with: "http") == true && showShareInToolbar {
                        ShareLink(item: location!) {
                            Image(systemName: "square.and.arrow.up")
                                .padding(Layout.controlPadding)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                        
                    }
                    
                    if showReloadInToolbar {
                        ReloadButton(state: browserState) {
                            if browserState.isLoading  {
                                browserState.webView?.stopLoading()
                            } else {
                                browserState.webView?.reload()
                            }
                        }
                    }
                }
                
                
                
                if showAddrBarInToolbar {
                    
                    HStack{
                        if location?.absoluteString.starts(with: "http") == true {
                            TrustIndicator(trust: browserState.webView?.serverTrust, url: location, isPresented: $showTrustInfo)
                                .popover(isPresented: $showTrustInfo) {
                                    ServerTrustView(trust: browserState.webView?.serverTrust, url: browserState.url,
                                                    onAttemptHTTPS: {
                                        location = URL(string: "https://" + location!.absoluteString.split(separator: ":")[1])
                                    }
                                    )
                                }
                                .padding(.leading)
                        }
                        
                        AddressField(text: $urlInput, onSubmit: submitURL)
                        
                        
                        Spacer()
                        
                        
                        if priv {
                            Image(systemName:"eye.slash.fill")
                                .help("Private Mode")
                                .padding(0.25)
                        }
                        
                        
                        if let pIcon = bProfileIcon {
                            Image(systemName: pIcon)
                                .help("Profile: \(bProfileName ?? "")")
                                .padding(.trailing, 10)
                        }
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .popover(isPresented: $showSuggestions) {
                        AutoFillPopover(searchTerm: $urlInput)
                    }
                    .sheet(isPresented: $showCommands) {
                        VStack(spacing: 0) {
                            CommandsView(searchText:$commandSearchText, searchQuery: $urlInput)
                            Button("Close") {
                                showCommands = false
                            }
                            .padding()
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .frame(width: 450, height: 600)
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
                }
                
                
                if(showFindNavigator) {
                    FindBarView(state:browserState)
                }
                
                if showSearchButtonInToolbar {
                    HStack(spacing: 12) {
                        Button(action: submitURL) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .padding(Layout.controlPadding)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                    }
                }
                    
                    if showAutocompleteInToolbar {
                        Button() {
                            showSuggestions.toggle()
                        } label: {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.title2)
                                .padding(Layout.controlPadding)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .keyboardShortcut("s", modifiers: [.command])
                    }
                    
                    if browserState.url != nil && browserState.url?.isFileURL == false && showExtInToolbar {
                        Button(action: {
                            showExtensionsPopover.toggle()
                        }) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.title2)
                                .padding(Layout.controlPadding)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .popover(isPresented: $showExtensionsPopover, arrowEdge: .bottom) {
                            ExtensionsPopoverView()
                                .frame(width: 350, height: 450)
                        }
                    }
                    
                    
                    if showMoreInToolbar {
                        Menu {
                            
                            
                            Button() {
                                showCommands = true
                            } label: {
                                Label("Palette", systemImage: "command.square")
                            }
                            .keyboardShortcut("k", modifiers: [.command])
                            
                            
                            Divider()
                            
                            Toggle("Sidebar",isOn:$showSidebar)
                            
                            Divider()
                            
                            if let url = location {
                                
                                Button() {
                                    showFindNavigator = !showFindNavigator
                                } label: {
                                    Label(showFindNavigator ? "Hide Find In Page" : "Find In Page", systemImage: "magnifyingglass")
                                }
                                .keyboardShortcut("f", modifiers: .command)
                                Divider()
                                
                                Menu() {
                                    Button() {
                                        browserState.zoomIn()
                                    } label: {
                                        Label("In", systemImage:"plus.magnifyingglass")
                                    }
                                    .keyboardShortcut("+", modifiers: .command)
                                    
                                    Button() {
                                        browserState.zoomOut()
                                    } label: {
                                        Label("Out", systemImage:"minus.magnifyingglass")
                                    }
                                    .keyboardShortcut("-", modifiers: .command)
                                    
                                    Divider()
                                    
                                    Button() {
                                        browserState.resetZoom()
                                    } label: {
                                        Label("Reset", systemImage: "arrow.clockwise.circle")
                                    }
                                } label: {
                                    Label("Zoom", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                                }
                                
                                Divider()
                                
                                if !paletteShowTabs {
                                    Button() {
                                        showTabSearch = true
                                    } label: {
                                        Label("Search Tabs", systemImage: "rectangle.and.text.magnifyingglass")
                                    }
                                    .keyboardShortcut("s", modifiers: [.command, .option])
                                }
                                
                                Divider()
                                
                                Button() {
                                    browserState.toggleMute()
                                } label: {
                                    browserState.isAudioMuted ? Label("Unmute Tab", systemImage:"speaker.slash") : Label("Mute Tab", systemImage:"speaker")
                                }
                                .keyboardShortcut("m", modifiers: [.command, .shift])
                                
                                Divider()
                                
                                
                                Menu {
                                    
                                    Button("In This Window", systemImage: "plus.square.on.square") {
                                        createNewTab(with: url)
                                    }
                                    Button("In New Window", systemImage: "macwindow.badge.plus") {
                                        createNewWindow(with: url)
                                    }
                                    
                                    
                                    Divider()
                                    
                                    Button {
                                        createFocusWindow(with: url, userAgent: userAgent)
                                    } label: {
                                        Label("Open in Focus", systemImage: "macwindow")
                                    }
                                    
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
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
                                
                                Menu() {
                                    
                                    Button("Bookmarks", systemImage: "star") {
                                        bookmarkStore.add(Bookmark(
                                            title: url.host() ?? "Unnamed",
                                            url: url.absoluteString
                                        ))
                                    }
                                    .keyboardShortcut("b", modifiers: [.command, .shift])
                                    
                                    
                                    Button("Sidebar", systemImage: "sidebar.left") {
                                        sidebarStore.add(SidebarItem(
                                            icon: "https://www.google.com/s2/favicons?domain=\(location?.host() ?? "")",
                                            url: location
                                        ))
                                    }
                                } label: {
                                    Label("Add Page To", systemImage: "plus")
                                }
                                
                                Divider()
                                
                                Button("Print Page", systemImage: "printer") {
                                    printCurrentPage()
                                }
                                .keyboardShortcut("p", modifiers: [.command])
                                
                                Divider()
                                
                                
                                Button("Reader Mode", systemImage: "eyeglasses") {
                                    showReader.toggle()
                                }
                                .keyboardShortcut("r", modifiers: [.command, .option])
                                
                                Divider()
                                
                                Menu {
                                    Button("Dev Tools", systemImage: "chevron.left.forwardslash.chevron.right") {
                                        let inspector = browserState.webView?.value(forKey: "inspector") as? NSObject
                                        inspector?.perform(NSSelectorFromString("show"))
                                    }
                                    .keyboardShortcut("i", modifiers: [.command, .option])
                                    
                                    
                                    Button() {
                                        let alert = NSAlert()
                                        alert.informativeText = "Enter new tab name:"
                                        alert.addButton(withTitle: "Rename")
                                        alert.addButton(withTitle: "Cancel")
                                        
                                        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                                        input.stringValue = browserState.customTitle ?? browserState.title
                                        input.placeholderString = browserState.webView?.title ?? "Page"
                                        alert.accessoryView = input
                                        alert.window.initialFirstResponder = input
                                        
                                        if alert.runModal() == .alertFirstButtonReturn {
                                            let newTitle = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if newTitle.isEmpty {
                                                browserState.customTitle = nil
                                                browserState.title = browserState.webView?.title ?? "Page"
                                            } else {
                                                browserState.customTitle = newTitle
                                                browserState.title = newTitle
                                            }
                                        }
                                    } label: {
                                        Label("Rename Tab", systemImage: "pencil")
                                    }
                                    
                                    
                                    Divider()
                                    
                                    Button {
                                        
                                        Task {
                                            await scanEvents()
                                        }
                                        
                                    } label: {
                                        Label("Add Events to Calendar", systemImage: "calendar")
                                    }
                                    
                                    Button {
                                        Task {
                                            summarizing = true
                                            await createSummaryWindow(state: browserState)
                                            summarizing = false
                                        }
                                    } label: {
                                        Label("Summarize", systemImage: "text.line.3.summary")
                                    }
                                    
                                    Button {
                                        
                                        Task {
                                            await cite()
                                        }
                                    } label: {
                                        Label("Cite", systemImage: "doc.text")
                                    }
                                    
                                    Divider()
                                    
                                    Button {
                                        createNewTab(with:URL(string:"https://github.com/systemsoftware/balance"))
                                    } label:{
                                        Label("Source Code", systemImage:"curlybraces")
                                    }
                                    
                                } label: {
                                    Label("More", systemImage: "ellipsis")
                                }
                                
                            }
                            
                        } label: {
                            Image(systemName: "ellipsis")
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
            
            if scanningForEvents {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Scanning for events...")
                }
            }
            
            if summarizing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Summarizing page...")
                }
            }
            
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
                        
                        
                        if showReader {
                            ReaderView(sourceWebView:browserState.webView!)
                                .zIndex(100)
                        }
                        
                        HStack(spacing: 8) {
                          
                            ZStack {
                                BrowserWebView(request:URLRequest(url: location ?? URL(string:homepage) ?? URL(string:"about:blank")!), state: browserState, priv:priv, profile:bProfile, userAgent: userAgent)
                                    .roundedBorderStyleNoFrame()
                                    .transition(.opacity)
                                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                                    .onChange(of: browserState.url) { oldValue, newValue in
                                        handleURLChange(from: oldValue, to: newValue)
                                    }

                                if let url = browserState.url ?? location, url.pathExtension.lowercased() == "pdf" && usePDFKit {
                                    PDFKitRepresentedView(url: url)
                                      
                                }
                            }
                            
                            if !splitURL.isEmpty {
                                BrowserWebView(request:URLRequest(url:URL(string:splitURL) ?? URL(string: "about:blank")!), state: splitState, priv:priv, profile:bProfile, userAgent: userAgent)
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
                                NoteView(tabID: tabID, browserState:browserState)
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
                                
                            case let str where str.contains("Map"):
                                MapView(browserState: browserState)
                                    .roundedBorderStyle()
                                
                            case let str where str.contains("RSS"):
                                RSSView()
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
                    if showSidebar {
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
                    }
                        .padding(.trailing, Layout.outerPadding)
                        .padding(.vertical, Layout.outerPadding)
                }
            
        }.onAppear {
            if let initialURLString {
                print("has initialURLString: \(initialURLString)")
                location = URL(string:initialURLString)
                urlInput = initialURLString
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
            guard newValue != nil else { return }
            if let web = browserState.webView {
                web.customUserAgent = userAgent
            }
        } .onAppear {
            sidebarPage.customUserAgent = userAgent
        }
        .onReceive(NotificationCenter.default.publisher(for: .openURLInNewTab)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                location = url
            }
        }
        .onAppear {
            updateTabState()
        }
        .background(WindowAccessor { window in
            if let window = window, window.identifier?.rawValue != tabID {
                window.identifier = NSUserInterfaceItemIdentifier(tabID)
                window.delegate = WindowDelegate.shared
                if !openWindows.contains(window) {
                    openWindows.append(window)
                }
            }
        })
        .onChange(of: location) { _, _ in updateTabState() }
        .onChange(of: splitURL) { _, _ in updateTabState() }
        .onChange(of: sidebarURL) { _, _ in updateTabState() }
        .onChange(of: showSidebar) { _, _ in updateTabState() }
        .onChange(of: browserState.scrollX) { _, _ in updateTabState() }
        .onChange(of: browserState.scrollY) { _, _ in updateTabState() }
        .onChange(of: splitState.scrollX) { _, _ in updateTabState() }
        .onChange(of: splitState.scrollY) { _, _ in updateTabState() }
        
    }
    
    @AppStorage("searchURL", store:Config.sharedDefaults) var searchURL = "https://www.google.com/search?q="

    // MARK: - Helper Methods
    
    private func updateTabState() {
        let state = TabSessionState(
            tabID: tabID,
            url: browserState.url?.absoluteString ?? location?.absoluteString,
            splitURL: splitURL.isEmpty ? nil : splitURL,
            sidebarURL: sidebarURL?.absoluteString,
            showSidebar: showSidebar,
            profile: bProfile,
            isPrivate: priv,
            scrollX: browserState.scrollX,
            scrollY: browserState.scrollY,
            splitScrollX: splitState.scrollX,
            splitScrollY: splitState.scrollY
        )
        TabRegistry.shared.states[tabID] = state
    }
    
    private func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
     //   guard !trimmed.isEmpty else { return }

        let url: URL?
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("webkit-extension://") || trimmed.hasPrefix("chrome-extension://") || trimmed.hasPrefix("file://") {
            url = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)")
        } else if(trimmed == "default-home" || trimmed.count == 0) {
            url = nil
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "\(searchURL)\(encoded)")
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
    
    
    private func cite() async {
        let style: String? = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Citation Style"
                alert.informativeText = "Enter citation style (e.g. APA, MLA, Chicago):"
                alert.addButton(withTitle: "Generate")
                alert.addButton(withTitle: "Cancel")
                
                let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                input.placeholderString = "APA"
                alert.accessoryView = input
                alert.window.initialFirstResponder = input
                
                if alert.runModal() == .alertFirstButtonReturn {
                    let val = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: val.isEmpty ? "APA" : val)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        guard let citationStyle = style else { return }
        
        let text = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                browserState.webView?.getCleanText { result in
                    continuation.resume(returning: result ?? "")
                }
            }
        }

        let pageURL = browserState.url?.absoluteString ?? "Unknown URL"
        let pageTitle = browserState.title

        let prompt = "Create a \(citationStyle) citation for this webpage. URL: \(pageURL). Title: \(pageTitle). Page content snippet: \(String(text.prefix(2000))). Generate only the citation and nothing else."
        
        let session = LanguageModelSession()
        
        do {
            let result = try await session.respond(to: prompt).content
            
            await MainActor.run {
                let successAlert = NSAlert()
                successAlert.messageText = "Citation Generated"
                successAlert.informativeText = "\(result) \n\n Note: this was generated by AI and make contain errors. Please verify and cite accordingly."
                successAlert.addButton(withTitle: "Copy")
                successAlert.addButton(withTitle: "Close")
                
                let response = successAlert.runModal()
                if response == .alertFirstButtonReturn {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(result, forType: .string)
                }
            }
            
        } catch {
            print(error)
            await MainActor.run {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Citation Error"
                errorAlert.informativeText = "Failed to generate citation: \(error.localizedDescription)"
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }
        }
        
    }
    
    private func scanEvents() async {
        
        scanningForEvents = true
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentDateString = ISO8601DateFormatter().string(from: Date())
        
        let text = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                browserState.webView?.getCleanText { result in
                    continuation.resume(returning: result ?? "")
                }
            }
        }
        
        let prompt = """
        You are an event extraction system.

        Extract ALL events from the text.

        Return ONLY valid JSON in this format:

        {
          "events": [
            {
              "name": "",
              "start": "yyyy-MM-dd:HH:mm:ss",
              "end": "yyyy-MM-dd:HH:mm:ss",
              "location": "",
              "notes": ""
            }
          ]
        }

        Rules:
        - If end time is unknown, infer a reasonable duration (default 2 hours)
        - Use ISO 8601 format for all dates: yyyy-MM-dd'T'HH:mm:ss
        - If no year assume \(currentYear), unless that passed \(currentDateString), then \(currentYear+1)
        - If only date is provided, assume 18:00 start
        - If no events exist, return {"events":[]}

        Text:
        \(insertEventDelimiters(String(text.prefix(2500))))
        """
        

        let opts = GenerationOptions(
            sampling: .greedy,
            temperature: 0.0
        )
        
        let session = LanguageModelSession()
        
        
        do {
            let result = try await session.respond(to: prompt, options:opts).content
            let cleanRes = cleanJSON(result)
            
            let data = Data(cleanRes.utf8)
            let decoded = try JSONDecoder().decode(EventExtraction.self, from: data)

            guard !decoded.events.isEmpty else { return }
            
            scanningForEvents = false
            
            let calManager = MacCalendarManager()

            if decoded.events.count == 1 {
                let e = decoded.events[0]
                calManager.presentAddEventPopup(
                    title: e.name,
                    startDateString: e.start,
                    endDateString: e.end,
                    location: e.location,
                    notes: e.notes
                )
            } else {
                showEventPicker(events: decoded.events) { selected in
                    calManager.presentAddEventPopup(
                        title: selected.name,
                        startDateString: selected.start,
                        endDateString: selected.end,
                        location: selected.location,
                        notes: selected.notes
                    )
                }
            }
            
        } catch {
            print(error)
            scanningForEvents = false
        }
        
    }

    func cleanJSON(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("```") {
            if let firstNewline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNewline)...])
            }
        }

        if let range = text.range(of: "```", options: .backwards) {
            text.removeSubrange(range)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleURLChange(from oldValue: URL?, to newValue: URL?) {
        guard let newURL = newValue else { return }
        
        urlInput = newURL.absoluteString
        updateTabState()
        
        if let scheme = newURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            if currentUserActivity == nil {
                currentUserActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            }
            currentUserActivity?.webpageURL = newURL
            currentUserActivity?.becomeCurrent()
        } else {
            currentUserActivity?.invalidate()
            currentUserActivity = nil
        }
        
        if priv == true { return }
        
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

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.callback(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
