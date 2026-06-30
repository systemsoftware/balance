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
    
    @Environment(\.modelContext) private var modelContext
    
    var downloadStore = DownloadStore()
    
    var body: some Scene {
        WindowGroup {
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
        .modelContainer(for: [HistoryItem.self]) 
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
    
    let contentView = ContentView(initialURL: url, pvt:pvt, profile:profile, profileIcon:profileIcon ?? "person.fill")
    
    newWindow.isReleasedWhenClosed = false
    newWindow.contentView = NSHostingView(rootView: contentView)
    
    newWindow.delegate = WindowDelegate.shared
    
    openWindows.append(newWindow)
    
    newWindow.makeKeyAndOrderFront(nil)
}

func createNewTab(with url: URL? = nil) {
    guard let currentWindow = NSApp.mainWindow ?? NSApp.windows.first else {
        createNewWindow()
        return
    }
    
    let contentView = ContentView(initialURL: url)
    
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
    
    openWindows.append(newWindow)
    
    currentWindow.addTabbedWindow(newWindow, ordered: .above)
    newWindow.makeKeyAndOrderFront(nil)
}

class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            openWindows.removeAll { $0 == window }
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
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
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
