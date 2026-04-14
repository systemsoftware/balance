import SwiftUI
import AppKit

var openWindows: [NSWindow] = []

@main
struct browserApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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

func createNewWindow() {
    let newWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    newWindow.isReleasedWhenClosed = false
    newWindow.contentView = NSHostingView(rootView: ContentView())
    
    newWindow.delegate = WindowDelegate.shared
    
    openWindows.append(newWindow)
    
    newWindow.makeKeyAndOrderFront(nil)
}

func createNewTab() {
    guard let currentWindow = NSApp.mainWindow ?? NSApp.windows.first else {
        createNewWindow()
        return
    }
    
    let newWindow = NSWindow(
        contentRect: currentWindow.frame,
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    newWindow.isReleasedWhenClosed = false
    newWindow.title = "New Tab"
    newWindow.contentView = NSHostingView(rootView: ContentView())
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
