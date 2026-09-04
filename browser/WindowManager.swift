import Foundation
import SwiftUI
import AppKit
internal import Combine

final class BrowserTabModel: ObservableObject, Identifiable, Hashable {
    let id: String
    let initialURL: URL?
    let isPrivate: Bool
    let profile: String
    let profileIcon: String
    let restoredState: TabSessionState?
    let browserState: BrowserState
    let splitState: BrowserState
    @Published var hasLoaded = false

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
        let restoredURL = restoredState?.url.flatMap(URL.init(string:))
        self.browserState = browserState ?? BrowserState(initialURL: restoredURL ?? initialURL)
        self.splitState = BrowserState(initialURL: restoredState?.splitURL.flatMap(URL.init(string:)))
        self.splitState.tabID = id + "_split"
        self.splitState.isPrivateBrowsing = self.isPrivate
        self.browserState.tabID = id
        self.browserState.isPrivateBrowsing = self.isPrivate
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

    // Flat compatibility view; browserWindows remains the single source of truth.
    var windows: [BrowserState] {
        browserWindows.flatMap { $0.tabs.map(\.browserState) }
    }

    @Published var currentSpaceIndex: Int = 0
    @Published var spaceNames: [String] = ["Space 1"]

    var openWindow: ((String) -> Void)?
    private var queuedWindowIDs: [String] = []
    private var didRestoreSavedSession = false
    private var pendingTabCleanup: [String: BrowserTabModel] = [:]

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
            self.currentSpaceIndex = min(max(session.currentSpaceIndex ?? 0, 0), names.count - 1)
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
                    spaceIndex: min(max(tabState.spaceIndex ?? currentSpaceIndex, 0), spaceNames.count - 1)
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
        openBrowserWindow(window.id)
        return window.id
    }

    @discardableResult
    func createTab(initialURL: URL? = nil, inBackground: Bool = false, providedState: BrowserState? = nil) -> String {
        // The app deliberately stays running after its last window closes. In
        // that state a new tab must also create and present a window; merely
        // calling ensureInitialWindow() would leave the new tab in an invisible
        // window model and make the command appear to have hung.
        guard let windowID = activeWindowID,
              let window = browserWindows.first(where: { $0.id == windowID }) else {
            let state = providedState ?? BrowserState()
            let tab = BrowserTabModel(
                initialURL: initialURL,
                browserState: state,
                spaceIndex: currentSpaceIndex
            )
            let window = BrowserWindowModel(tabs: [tab])
            browserWindows.append(window)
            activeWindowID = window.id
            openBrowserWindow(window.id)
            return tab.id
        }

        let sourceTab = window.activeTab
        let openInBackground = inBackground && (Config.sharedDefaults?.bool(forKey: "openLinksInBackground") ?? false)
        let tab = BrowserTabModel(
            initialURL: initialURL,
            isPrivate: sourceTab?.isPrivate ?? false,
            profile: sourceTab?.profile ?? "",
            profileIcon: sourceTab?.profileIcon ?? "person.fill",
            browserState: providedState,
            spaceIndex: currentSpaceIndex
        )
        tab.browserState.shouldAnimateTabInsertion = true

        // A focused control in the old tab remains first responder even after
        // its SwiftUI hierarchy becomes transparent. Resign it before changing
        // the active tab so keyboard input cannot be trapped in a hidden field.
        if !openInBackground {
            tabWindow(for: window)?.makeFirstResponder(nil)
        }
        window.tabs.append(tab)
        if !openInBackground {
            window.activeTabID = tab.id
        }
        objectWillChange.send()
        return tab.id
    }

    func selectTab(_ tabID: String) {
        guard let window = browserWindows.first(where: { $0.tabs.contains(where: { $0.id == tabID }) }) else { return }
        guard window.activeTabID != tabID || activeWindowID != window.id else { return }
        tabWindow(for: window)?.makeFirstResponder(nil)
        window.activeTabID = tabID
        let wasNotActive = activeWindowID != window.id
        activeWindowID = window.id
        window.activeTab?.browserState.isSleeping = false
        syncExtensionActiveTab()
        if wasNotActive {
            openBrowserWindow(window.id)
        }
        objectWillChange.send()
    }

    func closeTab(_ tabID: String) {
        guard let windowIndex = browserWindows.firstIndex(where: { $0.tabs.contains(where: { $0.id == tabID }) }) else { return }
        let window = browserWindows[windowIndex]
        guard let tabIndex = window.tabs.firstIndex(where: { $0.id == tabID }) else { return }

        // Resign any address/search/sidebar field while its full view hierarchy
        // still exists. AppKit can then repair the key-view loop before SwiftUI
        // removes the active tab's hosting views.
        if window.activeTabID == tabID {
            tabWindow(for: window)?.makeFirstResponder(nil)
        }

        // Determine next active tab BEFORE removing the current one to prevent SwiftUI from rendering a gray window
        if window.activeTabID == tabID && window.tabs.count > 1 {
            let nextActiveIndex = (tabIndex == window.tabs.count - 1) ? tabIndex - 1 : tabIndex + 1
            window.activeTabID = window.tabs[nextActiveIndex].id
        }

        let tab = window.tabs.remove(at: tabIndex)

        if !tab.isPrivate, let state = TabRegistry.shared.states[tabID] {
            SessionManager.shared.lastClosedURL = state.url
        }
        if tab.isPrivate || Config.sharedDefaults?.bool(forKey: "preserveOnClose") != true {
            Config.sharedDefaults?.removeObject(forKey: "note_\(tabID)")
        }

        scheduleCleanup(for: tab)

        if window.tabs.isEmpty {
            closeWindow(window.id)
            return
        }
        if activeWindowID == window.id {
            syncExtensionActiveTab()
        }
        objectWillChange.send()
    }

    func moveTab(_ fromTabID: String, toTabID targetTabID: String) {
        guard fromTabID != targetTabID else { return }
        guard let windowIndex = browserWindows.firstIndex(where: { $0.tabs.contains(where: { $0.id == fromTabID }) }) else { return }
        let window = browserWindows[windowIndex]
        
        guard let from = window.tabs.firstIndex(where: { $0.id == fromTabID }),
              let to = window.tabs.firstIndex(where: { $0.id == targetTabID }) else { return }
        
        withAnimation {
            window.tabs.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        objectWillChange.send()
    }

    func closeWindow(_ windowID: String) {
        guard let index = browserWindows.firstIndex(where: { $0.id == windowID }) else { return }
        tabWindow(for: browserWindows[index])?.makeFirstResponder(nil)
        let window = browserWindows.remove(at: index)
        for tab in window.tabs {
            if !tab.isPrivate, let state = TabRegistry.shared.states[tab.id] {
                SessionManager.shared.lastClosedURL = state.url
            }
            if tab.isPrivate || Config.sharedDefaults?.bool(forKey: "preserveOnClose") != true {
                Config.sharedDefaults?.removeObject(forKey: "note_\(tab.id)")
            }
            scheduleCleanup(for: tab)
        }

        if browserWindows.isEmpty {
            // We do not recreate a window here automatically because this prevents the app
            // from quitting when the last window closes.
            activeWindowID = nil
        } else if activeWindowID == windowID {
            activeWindowID = browserWindows.first?.id
        }
        syncExtensionActiveTab()
    }

    func renameSpace(at index: Int, to proposedName: String) {
        guard spaceNames.indices.contains(index) else { return }
        spaceNames[index] = proposedName.isEmpty ? "Space \(index + 1)" : proposedName
    }

    func removeSpace(at index: Int) {
        guard spaceNames.count > 1, spaceNames.indices.contains(index) else { return }

        let closingIDs = windows.filter { $0.spaceIndex == index }.map(\.tabID)
        for tabID in closingIDs {
            closeTab(tabID)
        }
        for tab in windows where tab.spaceIndex > index {
            tab.spaceIndex -= 1
        }

        spaceNames.remove(at: index)
        currentSpaceIndex = min(currentSpaceIndex, spaceNames.count - 1)
    }

    func tabs(inSameWindowAs tabID: String) -> [BrowserState] {
        guard let window = browserWindows.first(where: { $0.tabs.contains(where: { $0.id == tabID }) }) else {
            return windows.filter { $0.tabID == tabID }
        }
        return window.tabs.map(\.browserState)
    }

    func isActiveTab(_ tabID: String) -> Bool {
        guard let activeWindowID,
              let activeWindow = browserWindows.first(where: { $0.id == activeWindowID }) else {
            return false
        }
        return activeWindow.activeTabID == tabID
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
            // Window model already exists — just nudge observers so the
            // ProgressView placeholder re-evaluates and transitions to content.
            objectWillChange.send()
            return
        }
        

        
        let tab = BrowserTabModel(spaceIndex: currentSpaceIndex)
        let window = BrowserWindowModel(id: id, tabs: [tab])
        browserWindows.append(window)
        if activeWindowID == nil {
            activeWindowID = window.id
        }
    }

    private func openBrowserWindow(_ id: String) {
        if let openWindow {
            openWindow(id)
        } else if !queuedWindowIDs.contains(id) {
            queuedWindowIDs.append(id)
        }
    }

    private func syncExtensionActiveTab() {
        guard let activeWindowID,
              let window = browserWindows.first(where: { $0.id == activeWindowID }) else {
            WebExtensionManager.shared.activeTab = nil
            return
        }
        let activeState = window.activeTab?.browserState
        WebExtensionManager.shared.activeTab = activeState?.isPrivateBrowsing == true ? nil : activeState
    }

    private func tabWindow(for window: BrowserWindowModel) -> NSWindow? {
        for tab in window.tabs {
            if let nsWindow = tab.browserState.webView?.window {
                return nsWindow
            }
        }
        return NSApp.keyWindow
    }

    private func scheduleCleanup(for tab: BrowserTabModel) {
        pendingTabCleanup[tab.id] = tab

        // onDisappear normally drives teardown. Keep a fallback for tabs whose
        // window is destroyed before SwiftUI can deliver the lifecycle callback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.finishCleanup(tabID: tab.id)
        }
    }

    func finishCleanup(tabID: String) {
        guard let tab = pendingTabCleanup.removeValue(forKey: tabID) else { return }
        let closingIDs = [tabID, tabID + "_split"]

        tab.browserState.cleanup()
        tab.splitState.cleanup()
        let lingeringStates = WebExtensionManager.shared.allTabs.filter {
            closingIDs.contains($0.tabID)
        }
        for state in lingeringStates {
            state.cleanup()
        }
        TabRegistry.shared.states.removeValue(forKey: tabID)
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
            .background(
                WindowCloseObserver {
                    windowManager.closeWindow(windowID)
                }
            )
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
            .onChange(of: controlActiveState) { _, newState in
                if newState == .key {
                    windowManager.activeWindowID = windowID
                }
            }
    }
}


private struct WindowCloseObserver: NSViewRepresentable {
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClose = onClose
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    final class Coordinator {
        var onClose: () -> Void
        private weak var observedWindow: NSWindow?
        private var closeObserver: NSObjectProtocol?

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }

        func attach(to view: NSView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let window = view?.window,
                      window !== self.observedWindow else { return }
                self.stopObserving()
                self.observedWindow = window
                self.closeObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.willCloseNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.onClose()
                }
            }
        }

        func stopObserving() {
            if let closeObserver {
                NotificationCenter.default.removeObserver(closeObserver)
            }
            closeObserver = nil
            observedWindow = nil
        }

        deinit {
            stopObserving()
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
    @ObservedObject var tab: BrowserTabModel
    let activeTabID: String
    @EnvironmentObject private var windowManager: WindowManager

    init(tab: BrowserTabModel, activeTabID: String) {
        self.tab = tab
        self.activeTabID = activeTabID
    }

    var body: some View {
        let isActive = activeTabID == tab.id
        let state = tab.browserState

        Group {
            if tab.hasLoaded && !state.isSleeping {
                ContentView(
                    initialURL: tab.initialURL,
                    pvt: tab.isPrivate,
                    profile: tab.profile,
                    profileIcon: tab.profileIcon,
                    tabID: tab.id,
                    restoredState: tab.restoredState,
                    providedState: tab.browserState,
                    providedSplitState: tab.splitState
                )
                .environmentObject(windowManager)
                .opacity(isActive ? 1 : 0)
                .allowsHitTesting(isActive)
                .disabled(!isActive)
                .accessibilityHidden(!isActive)
            } else {
                // Lightweight placeholder — no focusable elements.
                Color.clear
            }
        }
        .task(id: isActive) {
            guard isActive, !tab.hasLoaded else { return }
            await Task.yield()
            guard !Task.isCancelled, activeTabID == tab.id else { return }
            tab.hasLoaded = true
        }
        .onDisappear {
            windowManager.finishCleanup(tabID: tab.id)
        }
    }

}
