import SwiftUI
import WebKit
import Foundation
import SwiftData
import FoundationModels
internal import UniformTypeIdentifiers

// MARK: - Layout Constants
enum Layout {
    static let outerPadding: CGFloat = 5
    static let controlPadding: CGFloat = 2
    static let toolbarButtonSize: CGFloat = 36
    static let cornerRadius: CGFloat = 20
    static let sidebarIconSize: CGFloat = 20
    static let sidebarIconPadding: CGFloat = 12
    static let sidebarItemSpacing: CGFloat = 6
}

struct SidebarItem: Identifiable, Codable {
    var id = UUID()
    var icon: String
    var url: URL?
    var view: String?
}


let builtInSidebar = [
    SidebarItem(icon: "message", view: "ChatView"),
    SidebarItem(icon: "envelope", view: "EmailView"),
    SidebarItem(icon: "bookmark", view: "BookmarksView"),
    SidebarItem(icon: "key", view: "PasswordsView"),
    SidebarItem(icon: "gearshape.fill", view: "SettingsView"),
    SidebarItem(icon:"note.text", view: "NotesView"),
    SidebarItem(icon:"clock.arrow.trianglehead.counterclockwise.rotate.90", view:"HistoryView"),
    SidebarItem(icon:"folder", view:"DownloadsView"),
    SidebarItem(icon:"puzzlepiece.extension", view:"ExtensionsView"),
    SidebarItem(icon:"hand.raised", view:"ContentBlockersView"),
    SidebarItem(icon:"map", view:"MapView"),
    SidebarItem(icon:"antenna.radiowaves.left.and.right", view:"RSSView"),
    SidebarItem(icon:"calendar", view:"CalendarView"),
    SidebarItem(icon:"cloud.sun", view: "WeatherView"),
    SidebarItem(icon: "bag", view: "InventoryView"),
    SidebarItem(icon: "internaldrive", view: "WebDataView")
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

enum BackgroundType: Int {
    case system = 0
    case light = 1
    case dark = 2
    case matchPage = 3
    case custom = 4
  

 }


struct AutoFillPopover: View {
    @Binding var searchTerm: String
    var body: some View {
        List {
            AutocompleteView(searchTerm: $searchTerm, loadQuery: {})
        }
        .listStyle(.inset)
        .frame(minWidth: 260, idealWidth: 350, maxWidth: 500, minHeight: 200, maxHeight: 300)
    }
}

struct ExtensionPopupView: PlatformViewRepresentable {
    let webView: WKWebView

    #if canImport(AppKit)
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    #else
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    #endif
}

struct ContentView: View {
    @ObservedObject private var extensionManager = WebExtensionManager.shared
    @EnvironmentObject private var windowManager: WindowManager
    @State private var urlInput: String = ""
    
    
    @State var showPageShine = false
    
    @State private var activeToolbarSheet: ToolbarSheet?

    @StateObject private var sidebarStore: SidebarStore
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var hasCompactHeight: Bool { verticalSizeClass == .compact }

    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    private var sidebarWidth: Int = 345
    
    @AppStorage("userAgent", store:Config.sharedDefaults)
    private var userAgent = DEFAULT_USER_AGENT
    
    @AppStorage("homepage", store: Config.sharedDefaults)
    private var homepage: String = "default-home"
    
    // 0: hidden, 1: only new tab, 2: always
    @AppStorage("bookmarkBar", store: Config.sharedDefaults)
    private var bookmarkBar: Int = 0
    
    @AppStorage("bookmarkbarLocation", store: Config.sharedDefaults)
    private var bookmarkBarLoc: Int = 0
    
    @AppStorage("backgroundType", store:Config.sharedDefaults)
    private var backgroundType: Int = 0

    @State private var sidebarURL: URL?
    
    @State private var showInspector = false
    
    @StateObject var browserState = BrowserState()
    
    @StateObject var splitState = BrowserState()
    
    private var location: URL? { browserState.url }
    

    private var locationBinding: Binding<URL?> {
        Binding(
            get: { browserState.url },
            set: { browserState.navigate(to: $0) }
        )
    }

    @State private var showingSidebarAddAlert = false
    @State private var draggedSidebarItem: SidebarItem?
    @State private var userInput = ""
    
    @State private var scanningForEvents = false
    @State private var summarizing = false
    
    @StateObject private var bookmarkStore: BookmarkStore
    
    @State private var sidebarPage = WebPage()
    
    @AppStorage("recordHistory", store:Config.sharedDefaults)
    private var recordHistory = true
    
    var initialURLString: String?
    
   @State private var splitURL: String = ""
    
    
    @State var falseBinding = false
    
    @AppStorage("leftSidebarWidth", store:Config.sharedDefaults) var leftSidebarWidth = 200
    
    @AppStorage("paletteShowTabs", store:Config.sharedDefaults) var paletteShowTabs: Bool = true
    
    @AppStorage("usePDFKit", store:Config.sharedDefaults) var usePDFKit: Bool = true
    
    @AppStorage("showSidebar", store:Config.sharedDefaults) var showSidebar = true
    
    @State private var showTrustInfo = false
    
    @State private var currentUserActivity: NSUserActivity?
    @AppStorage("enableHandoff", store:Config.sharedDefaults) var enableHandoff: Bool = true
    
    
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
            guard let data = try? JSONEncoder().encode(newValue),
                  let encoded = String(data: data, encoding: .utf8) else { return }
            profilesJSON = encoded
        }
    }

    var tabID: String
    var restoredState: TabSessionState?

    init(initialURL: URL? = nil, pvt: Bool = false, profile: String = "", profileIcon: String = "", tabID: String = UUID().uuidString, restoredState: TabSessionState? = nil, providedState: BrowserState? = nil, providedSplitState: BrowserState? = nil) {
        self.tabID = tabID
        let latestState = TabRegistry.shared.states[tabID] ?? restoredState
        self.restoredState = latestState
        
        let initURLString = providedState?.url?.absoluteString ?? latestState?.url ?? initialURL?.absoluteString
        if(initURLString != nil) { self.initialURLString = initURLString } else { print("nil initial url") }

        // For file:// URLs, preserve the original URL object so sandbox access
        // context is not lost when reconstructing from string.
        let initURL: URL?
        if let initial = initialURL, initial.isFileURL, latestState == nil, providedState == nil {
            initURL = initial
        } else {
            initURL = initURLString.flatMap { URL(string: $0) }
        }
        self._splitURL = State(initialValue: latestState?.splitURL ?? "")
        self._sidebarURL = State(initialValue: latestState?.sidebarURL != nil ? URL(string: latestState!.sidebarURL!) : nil)
        
        let resolvedProfile = restoredState?.profile ?? profile
        let defProfile = Config.sharedDefaults?.string(forKey: "defaultProfile") ?? ""
        let pProfile = resolvedProfile.isEmpty ? defProfile : resolvedProfile
        
        var localBProfile = pProfile
        var localBProfileIcon = profileIcon
        
        let allProfilesJSON = Config.sharedDefaults?.string(forKey: "profiles") ?? "[]"
        let allProfiles = (try? JSONDecoder().decode([Profile].self, from: Data(allProfilesJSON.utf8))) ?? []
        
        if localBProfile.isEmpty && !defProfile.isEmpty {
            localBProfile = defProfile
        }
        
        var localBProfileName: String? = nil
        if !localBProfile.isEmpty {
            if let matchedProfile = allProfiles.first(where: { $0.id.uuidString == localBProfile }) {
                if localBProfileIcon.isEmpty {
                    localBProfileIcon = matchedProfile.icon
                }
                localBProfileName = matchedProfile.name
            }
        }
        
        self.priv = restoredState?.isPrivate ?? pvt
        self.bProfile = localBProfile
        self.bProfileIcon = localBProfileIcon
        self.bProfileName = localBProfileName
        
        self._sidebarStore = StateObject(wrappedValue: SidebarStore(profile: localBProfile))
        self._bookmarkStore = StateObject(wrappedValue: BookmarkStore(profile: localBProfile))
        
        
        let initialBrowserState: BrowserState
        if let provided = providedState {
            initialBrowserState = provided
        } else {
            let newState = BrowserState(initialURL: initURL)
            newState.tabID = tabID
            newState.spaceIndex = WindowManager.shared.currentSpaceIndex
            initialBrowserState = newState
        }
        
        if initialBrowserState.webView == nil, let state = restoredState {
            initialBrowserState.restoredScrollX = state.scrollX
            initialBrowserState.restoredScrollY = state.scrollY
        }
        self._browserState = StateObject(wrappedValue: initialBrowserState)
        
        let initialSplitState: BrowserState
        if let provided = providedSplitState {
            initialSplitState = provided
        } else {
            let newState = BrowserState(initialURL: latestState?.splitURL.flatMap(URL.init(string:)))
            newState.tabID = tabID + "_split"
            initialSplitState = newState
        }

        if initialSplitState.webView == nil, let state = restoredState {
            initialSplitState.restoredScrollX = state.splitScrollX
            initialSplitState.restoredScrollY = state.splitScrollY
        }
        self._splitState = StateObject(wrappedValue: initialSplitState)
    }
    
    @State var showServerTrust = false
    @State private var showReader = false
    @State private var showExtensionsPopover = false
    
    @AppStorage("tabMode", store:Config.sharedDefaults) var leftSidebarMode: Int = 0
    @AppStorage("sidebarBackgroundType") var sidebarBackground = 1

    
    @State var commandSearchText = ""
    
    @State private var latestItem: HistoryItem?
    
    @State private var isSlideOverVisible = false
    
    @State private var events: [EventExtraction] = []
    
    @State private var showAddPopover = false
    @State private var addIndex = 0
    @State private var shouldAutoFocusAddress = true
    
    @AppStorage("toolbarLocation") var toolbarLocation = 0
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Address Bar

            if leftSidebarMode == 0 && !MemoryStorage.shared.focusMode {
                Tabs(browserState: browserState)
                    .frame(height: isCompact ? 44 : 50)
                    .frame(maxWidth: .infinity)
                    .padding(
                        .horizontal,
                        (isCompact ? 3 : Layout.outerPadding) + Layout.controlPadding + (isCompact ? 2 : 5)
                    )
                    .padding(toolbarLocation == 1 ? (isCompact ? 4 : 8) : 0)
            }
            
            if toolbarLocation == 0 && !MemoryStorage.shared.focusMode {
                BrowserToolbar(
                    browserState: browserState,
                    sidebarStore: sidebarStore,
                    bookmarkStore: bookmarkStore,
                    location: locationBinding,
                    urlInput: $urlInput,
                    showTrustInfo: $showTrustInfo,
                    activeSheet: $activeToolbarSheet,
                    summarizing: $summarizing,
                    splitURL: $splitURL,
                    splitState: splitState,
                    focusAddressOnAppear: initialURLString == nil && shouldAutoFocusAddress,
                    isPrivate: priv,
                    profileIcon: bProfileIcon,
                    profileName: bProfileName,
                    submitURL: submitURL,
                    scanEvents: scanEvents,
                    showReader: $showReader
                )
                .padding(.horizontal, isCompact ? 3 : Layout.outerPadding)
                .padding(.vertical, isCompact ? 4 : 8)
                .frame(maxWidth: .infinity)
            }
            
            
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
            
            if shouldShowBookmarks && bookmarkBarLoc == 0 {
                BookmarkBar(bookmarkStore: bookmarkStore)
                    .padding(.bottom, 5)
            }

            
            // MARK: - Web Content + Sidebar
            HStack(spacing: 0) {
                // MARK: - Web Content Area
                
                if leftSidebarMode == 2 && !MemoryStorage.shared.focusMode {
                    Tabs(browserState: browserState)
                        .frame(width: isCompact ? min(CGFloat(leftSidebarWidth), 160) : CGFloat(leftSidebarWidth))
                        .frame(maxHeight: .infinity)
                }
                
                ZStack {
                    if (location != nil) {
                        
                        
                        if showReader, let webView = browserState.webView {
                            ReaderView(sourceWebView: webView)
                                .zIndex(100)
                        }
                        
                        HStack(spacing: isCompact ? 4 : 8) {
                            
                            
                          
                            ZStack {
                                BrowserWebView(request:URLRequest(url: location ?? URL(string:homepage) ?? URL(string:"about:blank")!), state: browserState, priv:priv, profile:bProfile, userAgent: userAgent)
                                    .id(browserState.webViewIdentity)
                                    .roundedBorderStyleNoFrame(enabled: showPageShine)
                                    .clipShape(RoundedRectangle(cornerRadius: isCompact ? 14 : Layout.cornerRadius))
                                    .onChange(of: browserState.url) { oldValue, newValue in
                                        handleURLChange(from: oldValue, to: newValue)
                                    }
                                    .onChange(of: browserState.title) { _, newTitle in
                                        handleTitleChange(to: newTitle)
                                    }
#if os(iOS)
                                    .onTapGesture(count: 5) {
                                        toggleFocusMode()
                                    }
#endif
                                
                                if let url = browserState.url ?? location, url.pathExtension.lowercased() == "pdf" && usePDFKit {
                                    PDFKitRepresentedView(url: url)
                                      
                                }
                            }
                            
                            if !splitURL.isEmpty {
                                BrowserWebView(request: URLRequest(url: splitState.url ?? URL(string: "about:blank")!), state: splitState, priv: priv, profile: bProfile, userAgent: userAgent)
                                    .id(splitState.webViewIdentity)
                                    .roundedBorderStyleNoFrame()
                                    .clipShape(RoundedRectangle(cornerRadius: isCompact ? 14 : Layout.cornerRadius))
                            }
                        }
                    } else {
                        BrowserHomepage(profile: bProfile, state:browserState)
                            .clipShape(RoundedRectangle(cornerRadius: isCompact ? 14 : Layout.cornerRadius))
                            .task {
                                browserState.title = "Balance"
                            }
                        
                    }
                    
                    if leftSidebarMode == 1 && !MemoryStorage.shared.focusMode {
                        HStack(spacing: 0) {
                            ZStack(alignment: .leading) {
                                Color.clear
                                    .frame(width: isSlideOverVisible ? (isCompact ? min(CGFloat(leftSidebarWidth), 180) : CGFloat(leftSidebarWidth)) + 10 : 15)
                                    .frame(maxHeight: .infinity)
                                
                                if isSlideOverVisible {
                                    Tabs(browserState: browserState)
                                        .frame(width: isCompact ? min(CGFloat(leftSidebarWidth), 180) : CGFloat(leftSidebarWidth))
                                        .frame(maxHeight: .infinity)
                                        .glassEffect(.regular, in: .rect(cornerRadius: 15))
                                        .transition(.move(edge: .leading))
                                }
                            }
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isSlideOverVisible = hovering
                                }
                            }
                            
                            Spacer()
                        }
                        .zIndex(200)
                    }

                    if isCompact, let sidebarURL {
                            Color.black.opacity(0.35)
                            VStack(spacing: 0) {
                                sidebarDetailView(for: sidebarURL)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .glassEffect(in:.rect(cornerRadius: 20))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.leading, 32)
                            .padding(.vertical, 6)
                            .padding(.trailing, 2)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(300)
                    }
                }
                .padding(isCompact ? 3 : Layout.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    var descriptor = FetchDescriptor<HistoryItem>(
                        sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                    )
                    descriptor.fetchLimit = 1
                    
                    latestItem = try? modelContext.fetch(descriptor).first
                }
                
                
                // MARK: - Sidebar

                
                HStack(spacing: isCompact ? 4 : 8) {
                    if !isCompact, let sidebarURL {
                        sidebarDetailView(for: sidebarURL)
                            .glassEffect(in:.rect(cornerRadius: 20))
                            .frame(width: CGFloat(sidebarWidth))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    // MARK: Sidebar Items
                    if showSidebar && !MemoryStorage.shared.focusMode {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: isCompact ? 4 : Layout.sidebarItemSpacing) {
                                ForEach(sidebarStore.items) { item in
                                    Button(action: {
                                        toggleSidebar(sidebarTargetURL(for: item))
                                    }) {
                                        if item.icon.starts(with: "https") {
                                            Favicon(item.icon, width: isCompact ? 17 : Layout.sidebarIconSize, height: isCompact ? 17 : Layout.sidebarIconSize)
                                                .padding(isCompact ? 7 : Layout.sidebarIconPadding)
                                        } else {
                                            Image(systemName: item.icon)
                                                .font(.system(size: isCompact ? 17 : Layout.sidebarIconSize, weight: .regular))
                                                .frame(width: isCompact ? 17 : Layout.sidebarIconSize, height: isCompact ? 17 : Layout.sidebarIconSize)
                                                .padding(isCompact ? 7 : Layout.sidebarIconPadding)
                                        }
                                    }
                                    .glassEffect(sidebarBackground == 2 ? .regular : .identity)
                                    .padding(1)
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, isCompact ? 2 : 5)
                                    .onDrag {
                                        draggedSidebarItem = item
                                        return NSItemProvider(object: item.id.uuidString as NSString)
                                    }
                                    .onDrop(of: [.plainText], delegate: SidebarDropDelegate(item: item, store: sidebarStore, draggedItem: $draggedSidebarItem))
                                    .contextMenu {
                                        if sidebarStore.count() > 1 {
                                            Button("Remove", role: .destructive) {
                                                Task { @MainActor in
                                                    try? await Task.sleep(for: .milliseconds(200))
                                                    withAnimation(.bouncy) {
                                                        sidebarStore.remove(id: item.id)
                                                    }
                                                }
                                            }
                                            Divider()
                                        }
                                        Button("Add") {
                                            showAddPopover = true
                                        }
                                    }
                                    .id(item.id)
                                }
                            }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .background {
                            if sidebarBackground == 1 {
                                Capsule()
                                    .fill(.clear)
                                    .glassEffect(.regular, in: .capsule)
                                    .allowsHitTesting(false)
                                    .padding(.horizontal, isCompact ? 2 : 5)
                            }
                        }
                        .popover(isPresented: $showAddPopover, attachmentAnchor: .rect(.bounds),
                                 arrowEdge: .trailing) {
                            addSidebarPopover
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, isCompact ? 2 : Layout.outerPadding)
                    }
                }
                .padding(.trailing, isCompact ? 3 : Layout.outerPadding)
                .padding(.vertical, isCompact ? 3 : Layout.outerPadding)
            }
            
            
            
            if leftSidebarMode == 4 && !MemoryStorage.shared.focusMode {
                Tabs(browserState: browserState)
                    .frame(height: isCompact ? 44 : 50)
                    .frame(maxWidth: .infinity)
                    .padding(
                        .horizontal,
                        (isCompact ? 3 : Layout.outerPadding) + Layout.controlPadding + (isCompact ? 2 : 5)
                    )
                    .padding(.bottom, toolbarLocation == 0 ? (isCompact ? 6 : 10) : 0)
            }
            
            if toolbarLocation == 1 && !MemoryStorage.shared.focusMode {
                BrowserToolbar(
                    browserState: browserState,
                    sidebarStore: sidebarStore,
                    bookmarkStore: bookmarkStore,
                    location: locationBinding,
                    urlInput: $urlInput,
                    showTrustInfo: $showTrustInfo,
                    activeSheet: $activeToolbarSheet,
                    summarizing: $summarizing,
                    splitURL: $splitURL,
                    splitState: splitState,
                    focusAddressOnAppear: initialURLString == nil && shouldAutoFocusAddress,
                    isPrivate: priv,
                    profileIcon: bProfileIcon,
                    profileName: bProfileName,
                    submitURL: submitURL,
                    scanEvents: scanEvents,
                    showReader: $showReader
                )
                .padding(.horizontal, isCompact ? 3 : Layout.outerPadding)
                .padding(.vertical, isCompact ? 4 : 8)
                .frame(maxWidth: .infinity)
            }
            
            
            if shouldShowBookmarks && bookmarkBarLoc == 1 {
                BookmarkBar(bookmarkStore: bookmarkStore)
                    .padding(.vertical, isCompact ? 3 : Layout.outerPadding)
                    .padding(.bottom, 5)
            }
            
        }
        .sheet(item: $activeToolbarSheet) { sheet in
            toolbarSheet(sheet)
        }
        .onAppear {
            // The toolbar is removed in focus mode and inserted again when it
            // ends. Only auto-focus the address field for the initial mount;
            // focusing every reinsert can make AppKit rebuild a transient
            // SwiftUI key-view loop indefinitely.
            shouldAutoFocusAddress = false
            if let initialURLString {
                print("has initialURLString: \(initialURLString)")
                urlInput = initialURLString
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if homepage == "default-home" {
                    browserState.title = "Home"
                } else if let url = URL(string: homepage) {
                    browserState.navigate(to: url)
                } else {
                    print("Homepage URL was invalid: \(homepage)")
                }
            }
        }
        .onChange(of: sidebarURL) {
            sidebarPage.customUserAgent = userAgent
            guard let sidebarURL,
                  !sidebarURL.absoluteString.contains(".view"),
                  let scheme = sidebarURL.scheme?.lowercased(),
                  ["http", "https", "file"].contains(scheme)
            else { return }

            sidebarPage.load(sidebarURL)
        }.onChange(of: location) { _, newValue in
            guard newValue != nil else { return }
            if let web = browserState.webView {
                if userAgent != web.customUserAgent && !userAgent.isEmpty {
                    web.customUserAgent = userAgent
                }
            }
        }
        .onAppear {
            sidebarPage.customUserAgent = userAgent
        }
        .swiftUIPresentationHost()
        .onChange(of: windowManager.activeWindowID) { _, _ in
            guard windowManager.isActiveTab(tabID) else { return }
            if enableHandoff, let scheme = location?.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                if currentUserActivity == nil {
                    currentUserActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
                }
                currentUserActivity?.webpageURL = location
                currentUserActivity?.becomeCurrent()
            }
        }
        .onChange(of: enableHandoff) { _, newValue in
            if !newValue {
                currentUserActivity?.invalidate()
                currentUserActivity = nil
            } else if let scheme = location?.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                if currentUserActivity == nil {
                    currentUserActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
                }
                currentUserActivity?.webpageURL = location
                currentUserActivity?.becomeCurrent()
            }
        }
        .onAppear {
            updateTabState()
            if windowManager.isActiveTab(tabID), enableHandoff, let scheme = location?.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                if currentUserActivity == nil {
                    currentUserActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
                }
                currentUserActivity?.webpageURL = location
                currentUserActivity?.becomeCurrent()
            }
        }
        .onChange(of: location) { _, _ in updateTabState() }
        .onChange(of: splitURL) { _, newValue in
            splitState.navigate(to: newValue.isEmpty ? nil : URL(string: newValue))
            updateTabState()
        }
        .onChange(of: sidebarURL) { _, _ in updateTabState() }
        .onChange(of: showSidebar) { _, _ in updateTabState() }
        .onChange(of: browserState.scrollX) { _, _ in updateTabState() }
        .onChange(of: browserState.scrollY) { _, _ in updateTabState() }
        .onChange(of: splitState.scrollX) { _, _ in updateTabState() }
        .onChange(of: splitState.scrollY) { _, _ in updateTabState() }
        .focusedSceneValue(\.dispatchBrowserCommand, commandDispatcher)
    }

    private var commandDispatcher: ((BrowserCommand) -> Void)? {
        guard windowManager.isActiveTab(tabID) else { return nil }
        return handleBrowserCommand
    }

    @ViewBuilder
    private func toolbarSheet(_ sheet: ToolbarSheet) -> some View {
        switch sheet {
        case .commands:
            ToolbarCommandsSheet(searchText: $commandSearchText, searchQuery: $urlInput)
        case .tabSearch:
            ToolbarTabSearchSheet()
        case .events:
            EventListSheet(events: events)
        case .goTo:
            ToolbarGoToSheet(urlInput: $urlInput, submitURL: submitURL)
        case .restyle:
            BoostView(browserState: browserState, profile: bProfile)
        case .splitURL:
            ToolbarSplitURLSheet(splitURL: $splitURL)
        case .rename:
            ToolbarRenameSheet(browserState: browserState)
        case .summary:
            ToolbarSummarySheet(browserState: browserState, isSummarizing: $summarizing)
        }
    }

    private func handleBrowserCommand(_ command: BrowserCommand) {
            switch command {
            case .closeTab: WindowManager.shared.closeTab(tabID)
            case .searchTabs: activeToolbarSheet = .tabSearch
            case .zoomIn: browserState.zoomIn()
            case .zoomOut: browserState.zoomOut()
            case .resetZoom: browserState.resetZoom()
            case .toggleMute: browserState.toggleMute()
            case .duplicateTab: if let url = location { createNewTab(with: url) }
            case .duplicateWindow: if let url = location { createNewWindow(with: url) }
            case .openInFocus: withAnimation(.bouncy) { toggleFocusMode() }
            case .copyURL:
                if let url = location {
                    PlatformApplication.copy(url.absoluteString)
                }
            case .addToBookmarks:
                if let url = location,
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    bookmarkStore.add(Bookmark(
                        title: browserState.title.isEmpty ? (url.host() ?? "Unnamed") : browserState.title,
                        url: url.absoluteString
                    ))
                }
            case .addToSidebar:
                if let url = location,
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    print("Adding to sidebar: \(url.absoluteString)")
                    sidebarStore.add(SidebarItem(
                        icon: url.absoluteString,
                        url: url
                    ))
                }
            case .printPage: printCurrentPage()
            case .toggleReader: showReader.toggle()
            case .findInPage:
                PlatformApplication.dismissKeyboard()
                Task { @MainActor in
                    await Task.yield()
                    if browserState.isFindBarVisible {
                        browserState.findQuery = ""
                        browserState.isFindBarVisible = false
                    } else {
                        browserState.isFindBarVisible = true
                    }
                }
            case .renameTab:
#if canImport(AppKit)
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
#else
                SwiftUIPresentationCenter.shared.prompt(
                    "Rename Tab",
                    message: "Enter a new tab name.",
                    placeholder: browserState.webView?.title ?? "Page",
                    initialText: browserState.customTitle ?? browserState.title,
                    primaryTitle: "Rename"
                ) { value in
                    guard let value else { return }
                    let newTitle = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    browserState.customTitle = newTitle.isEmpty ? nil : newTitle
                    browserState.title = newTitle.isEmpty ? (browserState.webView?.title ?? "Page") : newTitle
                }
#endif
            case .summarize: Task { summarizing = true; await createSummaryWindow(state: browserState); summarizing = false }
            case .addEvents: Task { await scanEvents() }
            case .cite: Task { await cite() }
            case .downloads:
                let targetURL = URL(string: "DownloadsView.view")!
                toggleSidebar(targetURL)
            case .history:
                let targetURL = URL(string: "HistoryView.view")!
                toggleSidebar(targetURL)
            case .savePage:
#if canImport(AppKit)
                let panel = NSSavePanel()
                let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 44))
                let label = NSTextField(labelWithString: "Format:")
                label.isEditable = false
                label.isBordered = false
                label.drawsBackground = false
                label.frame = NSRect(x: 0, y: 14, width: 60, height: 20)
                let popup = NSPopUpButton(frame: NSRect(x: 60, y: 10, width: 150, height: 24), pullsDown: false)
                popup.addItems(withTitles: ["Web Archive", "HTML Source"])
                accessoryView.addSubview(label)
                accessoryView.addSubview(popup)
                panel.accessoryView = accessoryView
                
                let delegate = SavePanelAccessoryDelegate(panel: panel)
                popup.target = delegate
                popup.action = #selector(SavePanelAccessoryDelegate.formatChanged(_:))
                
                if #available(macOS 11.0, *) {
                    panel.allowedContentTypes = [.webArchive]
                } else {
                    panel.allowedFileTypes = ["webarchive"]
                }
                let fallbackTitle = browserState.title.isEmpty ? "page" : browserState.title
                panel.nameFieldStringValue = fallbackTitle
                
                if panel.runModal() == .OK, let url = panel.url {
                    let ext = url.pathExtension.lowercased()
                    if ext == "html" || ext == "htm" {
                        browserState.webView?.evaluateJavaScript("document.documentElement.outerHTML.toString()") { result, error in
                            if let html = result as? String {
                                try? html.write(to: url, atomically: true, encoding: .utf8)
                            } else {
                                print("Error getting HTML: \(String(describing: error))")
                            }
                        }
                    } else {
                        browserState.webView?.createWebArchiveData { result in
                            switch result {
                            case .success(let data):
                                try? data.write(to: url)
                            case .failure(let error):
                                print("Error creating web archive: \(error)")
                            }
                        }
                    }
                }
#endif
            case .reopenLastTab:
                if let urlStr = SessionManager.shared.lastClosedURL, let url = URL(string: urlStr) {
                    createNewTab(with:url)
                } else {
                    print("no last tab")
                }
            case .showSetup:
                setupWindow()
            case .reload:
                browserState.webView?.reload()
            case .forceReload:
                if let webView = browserState.webView,

                   let url = webView.url {

                    let request = URLRequest(

                        url: url,

                        cachePolicy: .reloadIgnoringLocalCacheData,

                        timeoutInterval: 10

                    )

                    webView.load(request)

                }
            case .shortcut:
#if canImport(AppKit)
                let savePanel = NSSavePanel()
                    savePanel.title = "Save Page"
                    savePanel.nameFieldStringValue = "\(location?.host ?? "page")"
                    savePanel.canCreateDirectories = false
                    savePanel.allowedContentTypes = [.bpage]
                    
                    savePanel.begin { response in
                        if response == .OK, let targetURL = savePanel.url {
                            do {
                                let urlString = location?.absoluteString ?? "about:blank"
                                try urlString.write(to: targetURL, atomically: true, encoding: .utf8)
                                print("Successfully saved file to: \(targetURL.path)")
                            } catch {
                                print("Failed to save file: \(error.localizedDescription)")
                            }
                        }
                    }
#endif
            case .goTo:
                activeToolbarSheet = .goTo
            }
    }
    
    @AppStorage("searchURL", store:Config.sharedDefaults) var searchURL = "https://www.google.com/search?q="

    // MARK: - Helper Methods

    
    @ViewBuilder
    private var addSidebarPopover: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Add Sidebar Item")
                .font(.headline)

            Picker("", selection: $addIndex.animation(.bouncy)) {
                Text("Built-in").tag(0)
                Text("Remote page").tag(1)
            }
            .pickerStyle(.segmented)

            if addIndex == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(availableBuiltInSidebar) { builtIn in
                            builtInSidebarButton(for: builtIn)
                        }
                    }
                }
                .scrollIndicators(.visible)
            } else {
                remoteSidebarItemForm
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .fittedMenuPopover(
            minHeight: hasCompactHeight ? 220 : 340,
            idealHeight: hasCompactHeight ? 300 : 440,
            maxHeight: hasCompactHeight ? 340 : 520
        )
    }

    private var availableBuiltInSidebar: [SidebarItem] {
        builtInSidebar.filter { candidate in
            !sidebarStore.items.contains { $0.view == candidate.view }
        }
    }

    private func builtInSidebarButton(for item: SidebarItem) -> some View {
        let rawTitle = item.view?.replacingOccurrences(of: "View", with: "") ?? item.icon
        let title = rawTitle.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )

        return Button {
            guard let view = item.view else { return }
            withAnimation(.bouncy) {
                sidebarStore.add(SidebarItem(icon: item.icon, view: view))
            }
            showAddPopover = false
        } label: {
            HStack {
                Image(systemName: item.icon)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.001))
        .cornerRadius(6)
    }

    private var remoteSidebarItemForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("https://example.com", text: $userInput)
                .autocorrectionDisabled()
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    showAddPopover = false
                }
                Button("Add") {
                    let sidebarItemURL = URL(string: userInput) ?? URL(fileURLWithPath: userInput)
                    sidebarStore.add(SidebarItem(icon: userInput, url: sidebarItemURL))
                    showAddPopover = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(userInput.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func sidebarDetailView(for sidebarURL: URL) -> some View {
        if sidebarURL.absoluteString.contains(".view") {
            switch sidebarURL.absoluteString {
            case let str where str.contains("Chat"):
                ChatView(browserState: browserState)
                
            case let str where str.contains("Bookmark"):
                BookmarksView(showAddBookmark: $falseBinding)
                
            case let str where str.contains("Settings"):
                SettingsView(activeProfile: bProfile)
                    .frame(maxWidth: .infinity)
                
            case let str where str.contains("Password"):
                PasswordsView()
                
            case let str where str.contains("Note"):
                NoteView(tabID: tabID, browserState: browserState)
                
            case let str where str.contains("History"):
                HistoryView(profile: bProfile)
                
            case let str where str.contains("Download"):
                DownloadsView(profile: bProfile)
                
            case let str where str.contains("Extension"):
                ExtensionsView()
                
            case let str where str.contains("ContentBlocker"):
                ContentBlockerView()
                
            case let str where str.contains("Map"):
                MapView(browserState: browserState)
                
            case let str where str.contains("RSS"):
                RSSView()
                
            case let str where str.contains("Calendar"):
                CalendarSidebarView()
                
            case let str where str.contains("Email"):
                EmailView(profile: bProfile)
                
            case let str where str.contains("Weather"):
                WeatherSidebarView()
                
            case let str where str.contains("Inventory"):
                InventorySidebar()
                
            case let str where str.contains("WebData"):
                WebDataView(profile: bProfile)

            default:
                EmptyView()
            }
        } else {
            WebView(sidebarPage)
                .frame(width: isCompact ? nil : CGFloat(sidebarWidth))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 14 : Layout.cornerRadius)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: isCompact ? 14 : Layout.cornerRadius))
        }
    }

    private func sidebarTargetURL(for item: SidebarItem) -> URL? {
        if let url = item.url {
            return url
        }
        guard let view = item.view else {
            return nil
        }
        return URL(string: view + ".view")
    }
    
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
            splitScrollY: splitState.scrollY,
            spaceIndex: browserState.spaceIndex
        )
        TabRegistry.shared.states[tabID] = state
    }
    
    private func setupWindow() {
        #if canImport(AppKit)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Welcome to Balance"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        
        let setupView = SetupView {
            DispatchQueue.main.async {
                window.close()
            }
        }
        .modelContainer(HistoryManager.sharedContainer)
        
        window.contentView = NSHostingView(rootView: setupView)
        window.makeKeyAndOrderFront(nil)
        #endif
    }
    
    private func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        //   guard !trimmed.isEmpty else { return }
        
        let url: URL?
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("extension://") || trimmed.hasPrefix("webkit-extension://") || trimmed.hasPrefix("chrome-extension://") || trimmed.hasPrefix("file://") {
            url = URL(string: trimmed)
        } else if trimmed.hasPrefix("/") {
            // Bare POSIX path (e.g. /Users/foo/bar/index.html) — load as file://
            url = URL(fileURLWithPath: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)")
        } else if(trimmed == "default-home" || trimmed.count == 0) {
            url = nil
        } else if trimmed.hasPrefix("localhost") {
                url = URL(string: "http://\(trimmed)")
            } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "\(searchURL)\(encoded)")
        }

        browserState.navigate(to: url)
    }

    private func toggleFocusMode() {
        guard location != nil else { return }

        // Repair the key-view loop while the current hierarchy still exists.
        // Changing focus mode removes or inserts several focusable controls.
        PlatformApplication.dismissKeyboard()
        Task { @MainActor in
            await Task.yield()
            MemoryStorage.shared.focusMode.toggle()
        }
    }

    private func toggleSidebar(_ targetURL: URL?) {
        let nextURL = sidebarURL == targetURL ? nil : targetURL
        PlatformApplication.dismissKeyboard()
        Task { @MainActor in
            await Task.yield()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                sidebarURL = nextURL
            }
        }
    }
    
   
    private func printCurrentPage() {
        guard let webView = browserState.webView else { return }

#if canImport(AppKit)
        let printInfo = NSPrintInfo()

        let operation = webView.printOperation(with: printInfo)

        // Force layout before printing
        operation.view?.frame = webView.bounds
        operation.view?.layoutSubtreeIfNeeded()

        operation.showsPrintPanel = true
        operation.showsProgressPanel = true

        if let window = webView.window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
#else
        webView.evaluateJavaScript("window.print()", completionHandler: nil)
#endif
    }
    
    
    private func cite() async {
#if canImport(AppKit)
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
#else
        let style: String? = await withCheckedContinuation { continuation in
            SwiftUIPresentationCenter.shared.prompt(
                "Citation Style",
                message: "Enter a citation style (for example APA, MLA, or Chicago).",
                placeholder: "APA",
                initialText: "APA",
                primaryTitle: "Generate"
            ) { value in
                continuation.resume(returning: value)
            }
        }
#endif
        
        guard let citationStyle = style else { return }
        
        guard let webView = browserState.webView else { return }
        let text = await withCheckedContinuation { continuation in
            webView.getTextForAI(maxCharacters: 2_000) { result in
                continuation.resume(returning: result ?? "")
            }
        }

        let pageURL = browserState.url?.absoluteString ?? "Unknown URL"
        let pageTitle = browserState.title

        let prompt = "Create a \(citationStyle) citation for this webpage. URL: \(pageURL). Title: \(pageTitle). Page content snippet: \(String(text.prefix(2000))). Generate only the citation and nothing else."
        
        let session = LanguageModelSession()
        
        do {
            let result = try await session.respond(to: prompt).content
            
            await MainActor.run {
#if canImport(AppKit)
                let successAlert = NSAlert()
                successAlert.messageText = "Citation Generated"
                successAlert.informativeText = "\(result) \n\n Note: this was generated by AI and may contain errors. Please verify and cite accordingly."
                successAlert.addButton(withTitle: "Copy")
                successAlert.addButton(withTitle: "Close")
                
                let response = successAlert.runModal()
                if response == .alertFirstButtonReturn {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(result, forType: .string)
                }
#else
                PlatformApplication.copy(result)
                windowAlert(message: "Citation generated and copied to the clipboard.")
#endif
            }
            
        } catch {
            print(error)
            await MainActor.run {
#if canImport(AppKit)
                let errorAlert = NSAlert()
                errorAlert.messageText = "Citation Error"
                errorAlert.informativeText = "Failed to generate citation: \(error.localizedDescription)"
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
#else
                windowAlert(message: "Failed to generate citation: \(error.localizedDescription)")
#endif
            }
        }
        
    }
    
    @MainActor
    func scanEvents() async {
        
        scanningForEvents = true
        defer { scanningForEvents = false }
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentDateString = ISO8601DateFormatter().string(from: Date())
        
        guard let webView = browserState.webView else { return }
        let text = await withCheckedContinuation { continuation in
            webView.getTextForAI(maxCharacters: 2_500) { result in
                continuation.resume(returning: result ?? "")
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
                events = [decoded]
                activeToolbarSheet = .events
            }
            
        } catch {
            print(error)
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
        
        if !priv, enableHandoff, let scheme = newURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
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
                profile: bProfile
            )
        }
    }
    
    @AppStorage("themePreference", store:Config.sharedDefaults) var themePreference = "system"
    
    
    private func handleTitleChange(to newTitle: String) {

        if priv == true { return }
        
        if recordHistory == true, let newURL = browserState.url, newURL.absoluteString != homepage {
            let historyTitle = newTitle.isEmpty ? (newURL.host() ?? "No Title") : newTitle
            let historyURL = newURL.absoluteString
            
            if themePreference == "match" {
                showPageShine = false
#if canImport(AppKit)
                Task {
                    let clr = await browserState.getBackground()
                    if let window = NSApplication.shared.keyWindow {
                        window.backgroundColor = clr
                        window.appearance = NSAppearance(named: clr.isLight ? .aqua : .darkAqua)
                    }
                }
#endif
            } else {
                showPageShine = true
            }
            
            HistoryManager.addToHistory(
                title: historyTitle,
                url: historyURL,
                profile: bProfile
            )
        }
    }

    
}

#if canImport(AppKit)
class SavePanelAccessoryDelegate: NSObject {
    let panel: NSSavePanel
    
    init(panel: NSSavePanel) {
        self.panel = panel
    }
    
    @objc func formatChanged(_ sender: NSPopUpButton) {
        let isHTML = sender.indexOfSelectedItem == 1
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = isHTML ? [.html] : [.webArchive]
        } else {
            panel.allowedFileTypes = isHTML ? ["html"] : ["webarchive"]
        }
    }
}
#endif
