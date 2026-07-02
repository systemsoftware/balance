import SwiftUI
import AppKit
import SwiftData
import AuthenticationServices

var openWindows: [NSWindow] = []

@main
struct browserApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("clearHistoryOnClose", store:Config.sharedDefaults)
    var clearHistoryOnClose: Bool = false
    
    @AppStorage("clearDownloadHistoryOnClose", store:Config.sharedDefaults)
    var clearDownloadHistoryOnClose: Bool = true
    
    @AppStorage("showTabsInDockMenu", store:Config.sharedDefaults)
    var showTabsInDockMenu: Bool = false
    
    @AppStorage("themePreference", store:Config.sharedDefaults)
    var themePreference: String = "system"
    
    @Environment(\.modelContext) private var modelContext
    
    var downloadStore = DownloadStore()
    
    private func applyTheme(_ theme: String) {
        switch theme {
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        default:
            NSApp.appearance = nil
        }
    }
    
    var body: some Scene {
        let firstTab = SessionManager.shared.popInitialTabState()
        
        WindowGroup {
            if let firstTab = firstTab {
                ContentView(
                    initialURL: firstTab.url != nil ? URL(string: firstTab.url!) : nil,
                    pvt: firstTab.isPrivate,
                    profile: firstTab.profile,
                    tabID: firstTab.tabID ?? UUID().uuidString,
                    restoredState: firstTab
                )
                .onAppear {
                    applyTheme(themePreference)
                }
                .onChange(of: themePreference) { _, newValue in
                    applyTheme(newValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    print("App is about to close.")
                    if(clearHistoryOnClose) {
                        HistoryManager.clearAllHistory()
                    }
                    if(clearDownloadHistoryOnClose) {
                        for download in downloadStore.items {
                            downloadStore.remove(id: download.id)
                        }
                    }
                }
            } else {
                ContentView()
                    .onAppear {
                    applyTheme(themePreference)
                }
                .onChange(of: themePreference) { _, newValue in
                    applyTheme(newValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                        print("App is about to close.")
                        if(clearHistoryOnClose) {
                            HistoryManager.clearAllHistory()
                        }
                        if(clearDownloadHistoryOnClose) {
                            for download in downloadStore.items {
                                downloadStore.remove(id: download.id)
                            }
                        }
                    }
            }
        }
        .onChange(of: showTabsInDockMenu) { _, _ in
            updateDockMenuTabsVisibility()
        }
        .modelContainer(HistoryManager.sharedContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    createNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("New Window") {
                    createNewWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            BrowserCommands()
        }
        
        SwiftUI.Settings {
            SettingsView(isStandalone: true)
                .frame(minWidth: 400, minHeight: 450)
        }
    }
}

func createNewWindow(with url: URL? = nil, pvt: Bool = false, profile: String = "", profileIcon: String? = "") {
    let newWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 800),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    if !profile.isEmpty {
        print("Using custom profile: \(profile)")
    }
    
    if let screen = NSScreen.main {
        let visibleFrame = screen.visibleFrame
        newWindow.setFrame(visibleFrame, display: true, animate: true)
    }
    
    newWindow.title = "Balance"
    
    let tabID = UUID().uuidString
    let contentView = ContentView(initialURL: url, pvt:pvt, profile:profile, profileIcon:profileIcon ?? "person.fill", tabID: tabID)
    
    newWindow.isReleasedWhenClosed = false
    newWindow.contentView = NSHostingView(rootView: contentView)
    
    newWindow.delegate = WindowDelegate.shared
    newWindow.identifier = NSUserInterfaceItemIdentifier(tabID)
    
    openWindows.append(newWindow)
    
    newWindow.makeKeyAndOrderFront(nil)
    updateDockMenuTabsVisibility()
}

func createNewTab(with url: URL? = nil, inBackground: Bool = false) {
    let browserWindows = NSApp.windows.filter { openWindows.contains($0) }
    let targetWindow: NSWindow?
    if let main = NSApp.mainWindow, openWindows.contains(main) {
        targetWindow = main
    } else {
        targetWindow = browserWindows.first
    }
    
    guard let currentWindow = targetWindow else {
        createNewWindow(with: url)
        return
    }
    
    let tabID = UUID().uuidString
    let contentView = ContentView(initialURL: url, tabID: tabID)
    
    let newWindow = NSWindow(
        contentRect: currentWindow.frame,
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    newWindow.title = "Balance"
    
    newWindow.isReleasedWhenClosed = false
    newWindow.contentView = NSHostingView(rootView: contentView)
    newWindow.delegate = WindowDelegate.shared
    newWindow.identifier = NSUserInterfaceItemIdentifier(tabID)
    
    openWindows.append(newWindow)
    
    let background = inBackground && (Config.sharedDefaults?.bool(forKey: "openLinksInBackground") ?? false)
    currentWindow.addTabbedWindow(newWindow, ordered: background ? .below : .above)
    if !background {
        newWindow.makeKeyAndOrderFront(nil)
    }
    updateDockMenuTabsVisibility()
}

class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowDidBecomeMain(_ notification: Notification) {
        updateDockMenuTabsVisibility()
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        updateDockMenuTabsVisibility()
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            // If this is the last open window, save the session BEFORE removing it
            // so that if the app terminates, the session isn't empty!
            if openWindows.count == 1 {
                SessionManager.shared.saveSession()
            }
            openWindows.removeAll { $0 == window }
            if let tabID = window.identifier?.rawValue {
                if let state = TabRegistry.shared.states[tabID] {
                    SessionManager.shared.lastClosedURL = state.url
                }
                if Config.sharedDefaults?.bool(forKey: "preserveOnClose") != true {
                    Config.sharedDefaults?.removeObject(forKey: "note_\(tabID)")
                }
            }
        }
    }
}

func updateDockMenuTabsVisibility() {
    let showTabs = Config.sharedDefaults?.object(forKey: "showTabsInDockMenu") as? Bool ?? false
    for window in openWindows {
        if showTabs {
            window.isExcludedFromWindowsMenu = false
        } else {
            if let tabGroup = window.tabGroup {
                window.isExcludedFromWindowsMenu = (tabGroup.selectedWindow != window)
            } else {
                window.isExcludedFromWindowsMenu = false
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 13.3, *) {
            let manager = ASAuthorizationWebBrowserPublicKeyCredentialManager()
            if manager.authorizationStateForPlatformCredentials == .notDetermined {
                Task {
                        await manager.requestAuthorizationForPublicKeyCredentials()                   
                }
            }
        }
        
        DispatchQueue.main.async {
            if let session = SessionManager.shared.getSessionState() {
                _ = SessionManager.shared.restoreSession(from: session)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SessionManager.shared.saveSession()
        return .terminateNow
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        
        let newWindowItem = NSMenuItem(
            title: "New Window",
            action: #selector(handleNewWindow),
            keyEquivalent: ""
        )
        newWindowItem.target = self
        
        menu.addItem(newWindowItem)
        
        let newPrivateWindowItem = NSMenuItem(
            title: "New Private Window",
            action: #selector(handleNewWindowPrivate),
            keyEquivalent: ""
        )
        newPrivateWindowItem.target = self
        
        menu.addItem(newPrivateWindowItem)
        
        return menu
    }
    
    @objc func handleNewWindow() {
        createNewWindow()
    }
    
    @objc func handleNewWindowPrivate() {
        createNewWindow(pvt: true)
    }
    
    @objc func newWindowForTab(_ sender: Any?) {
        createNewTab()
    }
}

enum MenuBarSection: String, CaseIterable {
    case browser = "Browser"
    case page = "Page"
}

enum BrowserCommand: String, CaseIterable {
    // Browser
    case palette, searchTabs, reopenLastTab
    // Page
    case toggleFind, zoomIn, zoomOut, resetZoom, toggleMute
    case duplicateTab, duplicateWindow, openInFocus
    case copyURL, printPage, toggleReader, renameTab
    case showDevTools
    case summarize, addEvents, cite
    
    var title: String {
        switch self {
        case .palette: return "Palette"
        case .searchTabs: return "Search Tabs"
        case .reopenLastTab: return "Reopen Closed Tab"
        case .toggleFind: return "Find In Page"
        case .zoomIn: return "In"
        case .zoomOut: return "Out"
        case .resetZoom: return "Reset"
        case .toggleMute: return "Mute"
        case .duplicateTab: return "In This Window"
        case .duplicateWindow: return "In New Window"
        case .openInFocus: return "Open in Focus"
        case .copyURL: return "Copy URL"
        case .printPage: return "Print"
        case .toggleReader: return "Reader"
        case .renameTab: return "Rename"
        case .showDevTools: return "Dev Tools"

        case .summarize: return "Summarize"
        case .addEvents: return "Add Events to Calendar"
        case .cite: return "Cite"
        }
    }
    
    var section: MenuBarSection {
        switch self {
        case .palette, .searchTabs, .reopenLastTab:
            return .browser
        default:
            return .page
        }
    }
    
    var submenu: String? {
        switch self {
        case .zoomIn, .zoomOut, .resetZoom:
            return "Zoom"
        case .duplicateTab, .duplicateWindow, .openInFocus:
            return "Duplicate"
        case .showDevTools:
            return "Developer"
        case .summarize, .addEvents, .cite:
            return "AI"
        default:
            return nil
        }
    }
    
    var shortcut: KeyboardShortcut? {
        switch self {
        case .palette: return KeyboardShortcut("k", modifiers: [.command])
        case .searchTabs: return KeyboardShortcut("s", modifiers: [.command, .option])
        case .reopenLastTab: return KeyboardShortcut("t", modifiers: [.command, .shift])
        case .toggleFind: return KeyboardShortcut("f", modifiers: [.command])
        case .zoomIn: return KeyboardShortcut("+", modifiers: [.command])
        case .zoomOut: return KeyboardShortcut("-", modifiers: [.command])
        case .toggleMute: return KeyboardShortcut("m", modifiers: [.command, .shift])
        case .copyURL: return KeyboardShortcut("c", modifiers: [.command, .control])
        case .printPage: return KeyboardShortcut("p", modifiers: [.command])
        case .toggleReader: return KeyboardShortcut("r", modifiers: [.command, .option])
        case .showDevTools: return KeyboardShortcut("i", modifiers: [.command, .option])
        default: return nil
        }
    }
    
    var requiresDividerAfter: Bool {
        switch self {
        case .palette, .searchTabs, .reopenLastTab: return true
        case .toggleFind, .resetZoom, .toggleMute, .openInFocus, .copyURL, .printPage, .toggleReader, .renameTab: return true
        case .zoomOut, .duplicateWindow: return true
        case .showDevTools: return true
        case .summarize, .addEvents: return true
        default: return false
        }
    }
}

struct BrowserCommandDispatcherKey: FocusedValueKey {
    typealias Value = (BrowserCommand) -> Void
}

extension FocusedValues {
    var dispatchBrowserCommand: ((BrowserCommand) -> Void)? {
        get { self[BrowserCommandDispatcherKey.self] }
        set { self[BrowserCommandDispatcherKey.self] = newValue }
    }
}

struct BrowserCommands: Commands {
    @FocusedValue(\.dispatchBrowserCommand) var dispatch
    
    var body: some Commands {
        CommandMenu("Browser") {
            MenuContent(section: .browser, dispatch: dispatch)
        }
        CommandMenu("Page") {
            MenuContent(section: .page, dispatch: dispatch)
        }
    }
}

struct MenuContent: View {
    let section: MenuBarSection
    let dispatch: ((BrowserCommand) -> Void)?
    
    var body: some View {
        let commands = BrowserCommand.allCases.filter { $0.section == section }
        let itemsAndGroups = getItemsAndGroups(from: commands)
        
        ForEach(itemsAndGroups, id: \.id) { itemOrGroup in
            if let group = itemOrGroup as? MenuGroup {
                Menu(group.name) {
                    ForEach(group.commands, id: \.self) { cmd in
                        CommandButton(command: cmd, dispatch: dispatch)
                    }
                }
                if group.requiresDividerAfter {
                    Divider()
                }
            } else if let item = itemOrGroup as? MenuItem {
                CommandButton(command: item.command, dispatch: dispatch)
                if item.command.requiresDividerAfter {
                    Divider()
                }
            }
        }
    }
}

struct CommandButton: View {
    let command: BrowserCommand
    let dispatch: ((BrowserCommand) -> Void)?
    
    var body: some View {
        Button(command.title) {
            dispatch?(command)
        }
        .keyboardShortcut(command.shortcut)
    }
}

protocol MenuElement: Identifiable {
    var id: String { get }
}

struct MenuItem: MenuElement {
    let command: BrowserCommand
    var id: String { command.rawValue }
}

struct MenuGroup: MenuElement {
    let name: String
    let commands: [BrowserCommand]
    var id: String { name }
    var requiresDividerAfter: Bool {
        commands.last?.requiresDividerAfter ?? false
    }
}

func getItemsAndGroups(from commands: [BrowserCommand]) -> [any MenuElement] {
    var result: [any MenuElement] = []
    var currentSubmenu: String? = nil
    var currentGroupCommands: [BrowserCommand] = []
    
    for command in commands {
        if let submenu = command.submenu {
            if currentSubmenu != submenu {
                if let current = currentSubmenu {
                    result.append(MenuGroup(name: current, commands: currentGroupCommands))
                }
                currentSubmenu = submenu
                currentGroupCommands = [command]
            } else {
                currentGroupCommands.append(command)
            }
        } else {
            if let current = currentSubmenu {
                result.append(MenuGroup(name: current, commands: currentGroupCommands))
                currentSubmenu = nil
                currentGroupCommands = []
            }
            result.append(MenuItem(command: command))
        }
    }
    
    if let current = currentSubmenu {
        result.append(MenuGroup(name: current, commands: currentGroupCommands))
    }
    
    return result
}
