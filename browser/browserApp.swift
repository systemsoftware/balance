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
    
    @Environment(\.modelContext) private var modelContext
    
    var downloadStore = DownloadStore()
    
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
        }
        
        SwiftUI.Settings {
            SettingsView(isStandalone: true)
                .frame(minWidth: 400, minHeight: 400)
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

func createNewTab(with url: URL? = nil) {
    guard let currentWindow = NSApp.mainWindow ?? NSApp.windows.first else {
        createNewWindow()
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
    
    currentWindow.addTabbedWindow(newWindow, ordered: .above)
    newWindow.makeKeyAndOrderFront(nil)
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
