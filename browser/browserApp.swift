import SwiftUI
import AppKit
import SwiftData

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
                    print("App is about to close. Perform cleanup here.")
                    if(clearDownloadHistoryOnClose) {
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

func createNewWindow(with url: URL? = nil) {
    let newWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    let contentView = ContentView(initialURL: url)
    
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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
