import Foundation
import SwiftUI
internal import Combine

final class BrowserTabModel: ObservableObject, Identifiable, Hashable {
    let id: String
    let initialURL: URL?
    let isPrivate: Bool
    let profile: String
    let profileIcon: String
    let restoredState: TabSessionState?
    let browserState: BrowserState

    init(
        id: String = UUID().uuidString,
        initialURL: URL? = nil,
        isPrivate: Bool = false,
        profile: String = "",
        profileIcon: String = "person.fill",
        restoredState: TabSessionState? = nil,
        browserState: BrowserState? = nil,
        spaceIndex: Int
    ) {
        self.id = id
        self.initialURL = initialURL
        self.isPrivate = restoredState?.isPrivate ?? isPrivate
        self.profile = restoredState?.profile ?? profile
        self.profileIcon = profileIcon
        self.restoredState = restoredState
        self.browserState = browserState ?? BrowserState()
        self.browserState.tabID = id
        self.browserState.spaceIndex = spaceIndex
        if let restoredState {
            self.browserState.restoredScrollX = restoredState.scrollX
            self.browserState.restoredScrollY = restoredState.scrollY
            TabRegistry.shared.states[id] = restoredState
        }
    }

    static func == (lhs: BrowserTabModel, rhs: BrowserTabModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class BrowserWindowModel: ObservableObject, Identifiable {
    var id: String
    @Published var tabs: [BrowserTabModel]
    @Published var activeTabID: String
    var frameString: String?

    init(id: String = UUID().uuidString, tabs: [BrowserTabModel], activeTabID: String? = nil, frameString: String? = nil) {
        self.id = id
        self.tabs = tabs
        self.activeTabID = activeTabID ?? tabs.first?.id ?? UUID().uuidString
        self.frameString = frameString
    }

    var activeTab: BrowserTabModel? {
        tabs.first { $0.id == activeTabID } ?? tabs.first
    }
}

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()

    @Published var browserWindows: [BrowserWindowModel] = []
    @Published var activeWindowID: String?

    // Kept as a BrowserState projection for existing sidebar/search/extension code.
    @Published var windows: [BrowserState] = []

    @Published var currentSpaceIndex: Int = 0
    @Published var spaceNames: [String] = ["Space 1"]

    var openWindow: ((String) -> Void)?
    private var queuedWindowIDs: [String] = []
    private var didRestoreSavedSession = false

    var initialWindowID: String {
        ensureInitialWindow()
    }

    @discardableResult
    func ensureInitialWindow() -> String {
        if let first = browserWindows.first {
            return first.id
        }

        if let session = SessionManager.shared.getSessionState(), !didRestoreSavedSession {
            restoreSession(session, openAdditionalWindows: false)
            if let first = browserWindows.first {
                return first.id
            }
        }

        let tab = BrowserTabModel(spaceIndex: currentSpaceIndex)
        let window = BrowserWindowModel(tabs: [tab])
        browserWindows = [window]
        activeWindowID = window.id
        rebuildTabProjection()
        return window.id
    }

    func registerOpenWindow(_ action: @escaping (String) -> Void) {
        openWindow = action
        let ids = queuedWindowIDs
        queuedWindowIDs.removeAll()
        for id in ids {
            action(id)
        }
    }

    func restoreSavedSessionIfNeeded() {
        guard !didRestoreSavedSession, let session = SessionManager.shared.getSessionState() else { return }
        restoreSession(session, openAdditionalWindows: true)
    }

    @discardableResult
    func restoreSession(_ session: SessionState, openAdditionalWindows shouldOpenAdditionalWindows: Bool) -> [String] {
        didRestoreSavedSession = true
        SessionManager.shared.isRestoring = true
        SessionManager.shared.restoredIDs = []
        
        if let names = session.spaceNames, !names.isEmpty {
            self.spaceNames = names
            self.currentSpaceIndex = session.currentSpaceIndex ?? 0
        }

        let restoredWindows = session.windows.compactMap { windowState -> BrowserWindowModel? in
            let tabs = windowState.tabs.enumerated().map { index, tabState in
                let tabID = tabState.tabID ?? UUID().uuidString
                SessionManager.shared.restoredIDs.append(tabID)
                return BrowserTabModel(
                    id: tabID,
                    initialURL: tabState.url.flatMap(URL.init(string:)),
                    isPrivate: tabState.isPrivate,
                    profile: tabState.profile,
                    restoredState: tabState,
                    spaceIndex: tabState.spaceIndex ?? currentSpaceIndex
                )
            }
            guard !tabs.isEmpty else { return nil }
            let activeIndex = min(max(windowState.activeTabIndex, 0), tabs.count - 1)
            return BrowserWindowModel(
                id: windowState.windowID ?? UUID().uuidString,
                tabs: tabs,
                activeTabID: tabs[activeIndex].id,
                frameString: windowState.frameString
            )
        }

        if !restoredWindows.isEmpty {
            browserWindows = restoredWindows
            activeWindowID = restoredWindows.first?.id
            rebuildTabProjection()
            if shouldOpenAdditionalWindows {
                for window in restoredWindows.dropFirst() {
                    openBrowserWindow(window.id)
                }
            }
        }

        SessionManager.shared.isRestoring = false
        return SessionManager.shared.restoredIDs
    }

    @discardableResult
    func createWindow(initialURL: URL? = nil, isPrivate: Bool = false, profile: String = "", profileIcon: String = "person.fill") -> String {
        let tab = BrowserTabModel(
            initialURL: initialURL,
            isPrivate: isPrivate,
            profile: profile,
            profileIcon: profileIcon,
            spaceIndex: currentSpaceIndex
        )
        let window = BrowserWindowModel(tabs: [tab])
        browserWindows.append(window)
        activeWindowID = window.id
        rebuildTabProjection()
        openBrowserWindow(window.id)
        return window.id
    }

    @discardableResult
    func createTab(initialURL: URL? = nil, inBackground: Bool = false, providedState: BrowserState? = nil) -> String {
        let windowID = activeWindowID ?? ensureInitialWindow()
        guard let window = browserWindows.first(where: { $0.id == windowID }) else {
            return createWindow(initialURL: initialURL)
        }

        let currentState = window.activeTab.flatMap { TabRegistry.shared.states[$0.id] }
        let openInBackground = inBackground && (Config.sharedDefaults?.bool(forKey: "openLinksInBackground") ?? false)
        let tab = BrowserTabModel(
            initialURL: initialURL,
            isPrivate: currentState?.isPrivate ?? false,
            profile: currentState?.profile ?? "",
            browserState: providedState,
            spaceIndex: currentSpaceIndex
        )
        window.tabs.append(tab)
        if !openInBackground {
            window.activeTabID = tab.id
        }
        rebuildTabProjection()
        objectWillChange.send()
        return tab.id
    }

    func selectTab(_ tabID: String) {
        guard let window = browserWindows.first(where: { $0.tabs.contains(where: { $0.id == tabID }) }) else { return }
        window.activeTabID = tabID
        let wasNotActive = activeWindowID != window.id
        activeWindowID = window.id
        if let tab = window.activeTab {
            tab.browserState.isSleeping = false
            WebExtensionManager.shared.activeTab = tab.browserState
        }
        if wasNotActive {
            openBrowserWindow(window.id)
        }
        objectWillChange.send()
    }

    func closeTab(_ tabID: String) {
        guard let windowIndex = browserWindows.firstIndex(where: { $0.tabs.contains(where: { $0.id == tabID }) }) else { return }
        let window = browserWindows[windowIndex]
        guard let tabIndex = window.tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = window.tabs.remove(at: tabIndex)

        if let state = TabRegistry.shared.states[tabID] {
            SessionManager.shared.lastClosedURL = state.url
        }
        if Config.sharedDefaults?.bool(forKey: "preserveOnClose") != true {
            Config.sharedDefaults?.removeObject(forKey: "note_\(tabID)")
        }

        cleanup(tabID: tab.id)
        tab.browserState.cleanup()
        TabRegistry.shared.states.removeValue(forKey: tabID)

        if window.tabs.isEmpty {
            closeWindow(window.id)
            return
        }

        if !window.tabs.contains(where: { $0.id == window.activeTabID }) {
            let nextIndex = min(tabIndex, window.tabs.count - 1)
            window.activeTabID = window.tabs[nextIndex].id
        }
        rebuildTabProjection()
        objectWillChange.send()
    }

    func closeWindow(_ windowID: String) {
        guard let index = browserWindows.firstIndex(where: { $0.id == windowID }) else { return }
        let window = browserWindows.remove(at: index)
        for tab in window.tabs {
            if let state = TabRegistry.shared.states[tab.id] {
                SessionManager.shared.lastClosedURL = state.url
            }
            cleanup(tabID: tab.id)
            tab.browserState.cleanup()
            TabRegistry.shared.states.removeValue(forKey: tab.id)
        }

        if browserWindows.isEmpty {
            // We do not recreate a window here automatically because this prevents the app
            // from quitting when the last window closes.
            activeWindowID = nil
        } else if activeWindowID == windowID {
            activeWindowID = browserWindows.first?.id
        }
        rebuildTabProjection()
    }

    func tabs(inSameWindowAs tabID: String) -> [BrowserState] {
        guard let window = browserWindows.first(where: { $0.tabs.contains(where: { $0.id == tabID }) }) else {
            return windows.filter { $0.tabID == tabID }
        }
        return window.tabs.map(\.browserState)
    }

    func isActiveTab(_ tabID: String) -> Bool {
        browserWindows.contains { $0.activeTabID == tabID }
    }

    func window(for id: String) -> BrowserWindowModel? {
        if let win = browserWindows.first(where: { $0.id == id }) {
            return win
        }
        

        
        return nil
    }

    func bindOrCreateWindow(for id: String) {
        if browserWindows.isEmpty {
            restoreSavedSessionIfNeeded()
        }
        
        if let _ = browserWindows.first(where: { $0.id == id }) {
            return
        }
        

        
        let tab = BrowserTabModel(spaceIndex: currentSpaceIndex)
        let window = BrowserWindowModel(id: id, tabs: [tab])
        browserWindows.append(window)
        if activeWindowID == nil {
            activeWindowID = window.id
        }
        rebuildTabProjection()
    }

    func rebuildTabProjection() {
        windows = browserWindows.flatMap { $0.tabs.map(\.browserState) }
    }

    private func openBrowserWindow(_ id: String) {
        if let openWindow {
            openWindow(id)
        } else if !queuedWindowIDs.contains(id) {
            queuedWindowIDs.append(id)
        }
    }

    private func cleanup(tabID: String) {
        let closingIDs = [tabID, tabID + "_split"]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let closingStates = WebExtensionManager.shared.allTabs.filter { closingIDs.contains($0.tabID) }
            for state in closingStates {
                state.cleanup()
            }
        }
    }
}

struct BrowserWindowHost: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.controlActiveState) private var controlActiveState
    @EnvironmentObject private var windowManager: WindowManager
    let windowID: String

    var body: some View {
        Group {
            if let window = windowManager.window(for: windowID) {
                BrowserWindowContent(window: window)
            } else {
                ProgressView()
                    .frame(width: 800, height: 800)
                    .onAppear {
                        windowManager.bindOrCreateWindow(for: windowID)
                    }
            }
        }
            .onAppear {
                windowManager.registerOpenWindow { id in
                    openWindow(value: id)
                }
                windowManager.activeWindowID = windowID
            }
            .onChange(of: windowManager.browserWindows.contains(where: { $0.id == windowID })) { _, exists in
                if !exists {
                    dismiss()
                }
            }
            .onDisappear {
                // Guard against SwiftUI calling onDisappear during view re-renders or
                // background transitions. Only close if the window still exists in the
                // model — if it was already removed (e.g., via the .onChange above when
                // `dismiss()` fired), calling closeWindow again would be a no-op, but
                // this guard also prevents false closures from transient SwiftUI teardowns.
                guard windowManager.window(for: windowID) != nil else { return }
                windowManager.closeWindow(windowID)
            }
            .onChange(of: controlActiveState) { _, newState in
                if newState == .key {
                    windowManager.activeWindowID = windowID
                }
            }
    }
}

private struct BrowserWindowContent: View {
    @ObservedObject var window: BrowserWindowModel

    var body: some View {
        ZStack {
            ForEach(window.tabs) { tab in
                BrowserWindowTabContainer(tab: tab, activeTabID: window.activeTabID)
            }
            if let activeTab = window.activeTab {
                ActiveTabTitleObserver(state: activeTab.browserState)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

private struct ActiveTabTitleObserver: View {
    @ObservedObject var state: BrowserState
    
    var body: some View {
        Color.clear
            .navigationTitle(state.title)
    }
}

private struct BrowserWindowTabContainer: View {
    @ObservedObject var state: BrowserState
    let tab: BrowserTabModel
    let activeTabID: String
    @EnvironmentObject private var windowManager: WindowManager
    
    init(tab: BrowserTabModel, activeTabID: String) {
        self.tab = tab
        self.state = tab.browserState
        self.activeTabID = activeTabID
    }
    
    var body: some View {
        if !state.isSleeping {
            ContentView(
                initialURL: tab.initialURL,
                pvt: tab.isPrivate,
                profile: tab.profile,
                profileIcon: tab.profileIcon,
                tabID: tab.id,
                restoredState: tab.restoredState,
                providedState: tab.browserState
            )
            .environmentObject(windowManager)
            .opacity(activeTabID == tab.id ? 1 : 0)
            .allowsHitTesting(activeTabID == tab.id)
            .accessibilityHidden(activeTabID != tab.id)
        }
    }
}
