import SwiftUI
import SwiftData
import AuthenticationServices
import WebKit
internal import Combine

func switchToTab(tabID: String) {
    WindowManager.shared.selectTab(tabID)
}

func handleDeepLink(_ url: URL) {
    guard let scheme = url.scheme,
          scheme == "balance" || scheme == "balance-focus"
    else { return }

    let isFocus = scheme == "balance-focus"

    guard let host = url.host else {
        print("No host in deep link:", url)
        return
    }

    var components = URLComponents()
    components.scheme = "https"
    components.host = host
    components.path = url.path
    components.query = url.query

    guard let destination = components.url else {
        print("Failed converting:", url)
        return
    }

    print("Opening:", destination)

    if isFocus {
        createFocusWindow(with: destination)
    } else {
        createNewTab(with: destination)
    }
}

@main
struct browserApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("clearHistoryOnClose", store:Config.sharedDefaults)
    var clearHistoryOnClose: Bool = false
    
    @AppStorage("clearDownloadHistoryOnClose", store:Config.sharedDefaults)
    var clearDownloadHistoryOnClose: Bool = true
    
    @AppStorage("clearCacheOnClose", store:Config.sharedDefaults)
    var clearCacheOnClose: Bool = false
    
    @AppStorage("clearCookiesOnClose", store:Config.sharedDefaults)
    var clearCookiesOnClose: Bool = false
    
    
    @AppStorage("themePreference", store:Config.sharedDefaults)
    var themePreference: String = "system"
    
    @Environment(\.modelContext) private var modelContext
    
    var downloadStore = DownloadStore()
    
    init () {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
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
        WindowGroup(for: String.self) { $windowID in
            BrowserWindowHost(windowID: windowID ?? WindowManager.shared.initialWindowID)
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
                    cleanTemporaryDirectory()
                }
        }
        .modelContainer(HistoryManager.sharedContainer)
        .environmentObject(WindowManager.shared)
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
            CommandGroup(replacing: .saveItem) {}
            BrowserCommands()
        }
        
        SwiftUI.Settings {
            SettingsView(isStandalone: true)
                .frame(minWidth: 400, minHeight: 450)
        }
    }
}

func createNewWindow(with url: URL? = nil, pvt: Bool = false, profile: String = "", profileIcon: String? = "") {
    if !profile.isEmpty {
        print("Using custom profile: \(profile)")
    }
    WindowManager.shared.createWindow(initialURL: url, isPrivate: pvt, profile: profile, profileIcon: profileIcon ?? "person.fill")
}

func createNewTab(with url: URL? = nil, inBackground: Bool = false, browserState: BrowserState? = nil) {
    WindowManager.shared.createTab(initialURL: url, inBackground: inBackground, providedState: browserState)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL, url.pathExtension == "bpage" {
                if let content = try? String(contentsOf: url, encoding: .utf8),
                   let parsedURL = URL(string: content.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    createNewTab(with: parsedURL)
                }
            } else {
                handleDeepLink(url)
            }
        }
    }

    @objc func handleAppleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
           let url = URL(string: urlString) {
            handleDeepLink(url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 13.3, *) {
            let manager = ASAuthorizationWebBrowserPublicKeyCredentialManager()
            if manager.authorizationStateForPlatformCredentials == .notDetermined {
                Task {
                        await manager.requestAuthorizationForPublicKeyCredentials()                   
                }
            }
        }
        
        WindowManager.shared.restoreSavedSessionIfNeeded()
        
        // Show setup window on first launch
        let defaults = Config.sharedDefaults ?? UserDefaults.standard
        if !defaults.bool(forKey: "sawSetup") {
            DispatchQueue.main.async {
                SetupWindowManager.shared.showSetupWindow()
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SessionManager.shared.saveSession()
        
        let defaults = Config.sharedDefaults ?? UserDefaults.standard
        let clearCache = defaults.bool(forKey: "clearCacheOnClose")
        let clearCookies = defaults.bool(forKey: "clearCookiesOnClose")
        
        if clearCache || clearCookies {
            var types = Set<String>()
            if clearCache {
                types.formUnion([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache, WKWebsiteDataTypeServiceWorkerRegistrations])
            }
            if clearCookies {
                types.insert(WKWebsiteDataTypeCookies)
            }
            
            WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: Date.distantPast) {
                if clearCache {
                    if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                        let webKitCache = cacheURL.appendingPathComponent("WebKit")
                        try? FileManager.default.removeItem(at: webKitCache)
                    }
                    URLCache.shared.removeAllCachedResponses()
                }
                sender.reply(toApplicationShouldTerminate: true)
            }
            
            // Fallback timeout in case removeData hangs due to lingering web views
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                sender.reply(toApplicationShouldTerminate: true)
            }
            
            return .terminateLater
        }
        
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
    case palette, searchTabs, reopenLastTab, downloads, history, autocomplete, showSetup
    // Page
    case reload, toggleFind, zoomIn, zoomOut, resetZoom, toggleMute
    case duplicateTab, duplicateWindow, openInFocus
    case copyURL, printPage, toggleReader, renameTab, savePage
    case showDevTools, forceReload
    case summarize, addEvents, cite
    case shortcut, closeTab
    
    var title: String {
        switch self {
        case .palette: return "Palette"
        case .showSetup: return "Setup & Import"
        case .searchTabs: return "Search All Tabs"
        case .reopenLastTab: return "Reopen Closed Tab"
        case .downloads: return "Downloads"
        case .history: return "History"
        case .autocomplete: return "Autocomplete"
        case .reload: return "Reload Page"
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
        case .renameTab: return "Rename Tab"
        case .savePage: return "Save Page As..."
        case .showDevTools: return "Dev Tools"
        case .forceReload: return "Reload Ignoring Cache"
        case .summarize: return "Summarize"
        case .addEvents: return "Add Events to Calendar"
        case .cite: return "Cite"
        case .shortcut: return "Save Shortcut"
        case .closeTab: return "Close Tab"
        }
    }
    
    var section: MenuBarSection {
        switch self {
        case .palette, .searchTabs, .reopenLastTab, .downloads, .history, .autocomplete, .showSetup:
            return .browser
        default:
            return .page
        }
    }
    
    var submenu: String? {
        switch self {
        case .zoomIn, .zoomOut, .resetZoom:
            return "Zoom"
        case .duplicateTab, .duplicateWindow:
            return "Duplicate"
        case .showDevTools, .forceReload:
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
        case .reload: return KeyboardShortcut("r", modifiers: [.command])
        case .searchTabs: return KeyboardShortcut("s", modifiers: [.command, .control])
        case .reopenLastTab: return KeyboardShortcut("t", modifiers: [.command, .shift])
        case .autocomplete: return KeyboardShortcut("s", modifiers: [.command])
        case .toggleFind: return KeyboardShortcut("f", modifiers: [.command])
        case .zoomIn: return KeyboardShortcut("+", modifiers: [.command])
        case .zoomOut: return KeyboardShortcut("-", modifiers: [.command])
        case .toggleMute: return KeyboardShortcut("m", modifiers: [.command, .shift])
        case .copyURL: return KeyboardShortcut("c", modifiers: [.command, .control])
        case .printPage: return KeyboardShortcut("p", modifiers: [.command])
        case .savePage: return KeyboardShortcut("s", modifiers: [.command, .option])
        case .toggleReader: return KeyboardShortcut("r", modifiers: [.command, .option])
        case .downloads: return KeyboardShortcut("d", modifiers: [.command, .shift])
        case .history: return KeyboardShortcut("y", modifiers: [.command])
        case .showDevTools: return KeyboardShortcut("i", modifiers: [.command, .option])
        case .summarize: return KeyboardShortcut("/", modifiers: [.command])
        case .addEvents: return KeyboardShortcut("/", modifiers: [.command, .option])
        case .forceReload: return KeyboardShortcut("r", modifiers: [.command, .shift])
        case .closeTab: return KeyboardShortcut("w", modifiers: [.command])
        default: return nil
        }
    }
    
    var requiresDividerAfter: Bool {
        switch self {
        case .palette, .reload, .searchTabs, .reopenLastTab, .downloads, .history, .autocomplete: return true
        case .toggleFind, .resetZoom, .toggleMute, .openInFocus, .copyURL, .printPage, .toggleReader, .renameTab, .savePage: return true
        case .zoomOut, .duplicateWindow: return true
        case .showDevTools: return true
        case .summarize, .addEvents, .forceReload, .cite, .shortcut: return true
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
            if let dispatch = dispatch {
                dispatch(command)
            } else if command == .closeTab {
                NSApp.keyWindow?.performClose(nil)
            }
        }
        .keyboardShortcut(command.shortcut)
        .disabled(dispatch == nil && command != .closeTab)
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


func cleanTemporaryDirectory() {
    let tmpDir = FileManager.default.temporaryDirectory
    do {
        let tmpFiles = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
        for file in tmpFiles {
            try FileManager.default.removeItem(at: file)
        }
    } catch {
        print("Failed to clear tmp: \(error)")
    }
}
