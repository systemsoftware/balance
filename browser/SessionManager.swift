import Foundation
import AppKit
import SwiftUI

struct SessionState: Codable {
    var windows: [WindowSessionState]
}

struct WindowSessionState: Codable {
    var tabs: [TabSessionState]
    var frameString: String?
    var activeTabIndex: Int
}

struct TabSessionState: Codable {
    var tabID: String?
    var url: String?
    var splitURL: String?
    var sidebarURL: String?
    var showSidebar: Bool
    var profile: String
    var isPrivate: Bool
    var scrollX: Int
    var scrollY: Int
    var splitScrollX: Int
    var splitScrollY: Int
}

class TabRegistry {
    static let shared = TabRegistry()
    var states: [String: TabSessionState] = [:]
}

class SessionManager {
    static let shared = SessionManager()
    
    var isRestoring = false
    var restoredIDs: [String] = []
    
    func saveSession() {
        print("saveSession: appGroupIdentifier = \(Config.appGroupIdentifier)")
        guard let defaults = Config.sharedDefaults else {
            print("saveSession: defaults nil")
            return
        }
        
        let preserve = defaults.object(forKey: "preserveOnClose") as? Bool ?? true
        if !preserve {
            print("saveSession: preserveOnClose is false")
            return
        }
        
        var sessionWindows: [WindowSessionState] = []
        var processedWindows = Set<NSWindow>()
        
        print("saveSession: openWindows count = \(openWindows.count)")
        for window in openWindows {
            if processedWindows.contains(window) { continue }
            processedWindows.insert(window)
            
            guard let tabIDRaw = window.identifier?.rawValue else {
                print("saveSession: window has no identifier!")
                continue
            }
            
            guard TabRegistry.shared.states[tabIDRaw] != nil else {
                print("saveSession: no TabRegistry state for tabID \(tabIDRaw)")
                continue
            }
            
            let tabs = window.tabbedWindows ?? [window]
            var tabStates: [TabSessionState] = []
            var activeIndex = 0
            
            for (_, tabWindow) in tabs.enumerated() {
                processedWindows.insert(tabWindow)
                
                if let tabID = tabWindow.identifier?.rawValue,
                   let state = TabRegistry.shared.states[tabID] {
                    tabStates.append(state)
                }
            }
            
            if !tabStates.isEmpty {
                let selectedWindow = window.tabGroup?.selectedWindow ?? window
                if let selectedIdx = tabs.firstIndex(of: selectedWindow) {
                    activeIndex = selectedIdx
                }
                
                sessionWindows.append(WindowSessionState(
                    tabs: tabStates,
                    frameString: NSStringFromRect(window.frame),
                    activeTabIndex: activeIndex
                ))
            }
        }
        
        if let data = try? JSONEncoder().encode(SessionState(windows: sessionWindows)) {
            defaults.set(data, forKey: "savedSessionState")
            defaults.synchronize()
        }
    }
    
    var hasConsumedInitialSession = false

    func getSessionState() -> SessionState? {
        guard let defaults = Config.sharedDefaults else { return nil }
        
        let preserve = defaults.object(forKey: "preserveOnClose") as? Bool ?? true
        guard preserve,
              let data = defaults.data(forKey: "savedSessionState"),
              let session = try? JSONDecoder().decode(SessionState.self, from: data),
              !session.windows.isEmpty else {
            return nil
        }
        return session
    }
    
    func popInitialTabState() -> TabSessionState? {
        if hasConsumedInitialSession { return nil }
        hasConsumedInitialSession = true
        return getSessionState()?.windows.first?.tabs.first
    }
    
    func restoreSession(from session: SessionState) -> [String] {
        isRestoring = true
        restoredIDs = []
        
        var isFirstWindow = true
        for winState in session.windows {
            var firstWindow: NSWindow?
            for (index, tabState) in winState.tabs.enumerated() {
                let tabID = tabState.tabID ?? UUID().uuidString
                restoredIDs.append(tabID)
                TabRegistry.shared.states[tabID] = tabState
                
                if isFirstWindow && index == 0 {
                    continue
                }
                
                let contentView = ContentView(
                    initialURL: tabState.url != nil ? URL(string: tabState.url!) : nil,
                    pvt: tabState.isPrivate,
                    profile: tabState.profile,
                    profileIcon: "person.fill",
                    tabID: tabID,
                    restoredState: tabState
                )
                
                let newWindow = NSWindow(
                    contentRect: winState.frameString != nil ? NSRectFromString(winState.frameString!) : NSRect(x: 0, y: 0, width: 800, height: 800),
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
                
                if index == 0 {
                    firstWindow = newWindow
                    newWindow.makeKeyAndOrderFront(nil)
                } else {
                    firstWindow?.addTabbedWindow(newWindow, ordered: .above)
                }
                
                if index == winState.activeTabIndex {
                    newWindow.makeKeyAndOrderFront(nil)
                }
            }
            
            isFirstWindow = false
        }
        
        isRestoring = false
        return restoredIDs
    }
}
