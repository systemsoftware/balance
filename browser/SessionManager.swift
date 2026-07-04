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
    var lastClosedURL: String? = nil
    
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
        
        let sidebarActive = (Config.sharedDefaults?.integer(forKey: "leftSidebarMode") ?? 0) != 0
        
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
            
            var tabWindows: [NSWindow]
            if sidebarActive {
                let groupID = tabGroups[tabIDRaw] ?? tabIDRaw
                tabWindows = openWindows.filter { w in
                    guard let wID = w.identifier?.rawValue else { return false }
                    return (tabGroups[wID] ?? wID) == groupID
                }
            } else {
                tabWindows = window.tabbedWindows ?? [window]
            }
            
            var tabStates: [TabSessionState] = []
            var activeIndex = 0
            
            for (_, tabWindow) in tabWindows.enumerated() {
                processedWindows.insert(tabWindow)
                
                if let tabID = tabWindow.identifier?.rawValue,
                   let state = TabRegistry.shared.states[tabID] {
                    tabStates.append(state)
                }
            }
            
            if !tabStates.isEmpty {
                if sidebarActive {
                    // Active tab is the key window
                    if let keyID = NSApp.keyWindow?.identifier?.rawValue,
                       let idx = tabWindows.firstIndex(where: { $0.identifier?.rawValue == keyID }) {
                        activeIndex = idx
                    }
                } else {
                    let selectedWindow = window.tabGroup?.selectedWindow ?? window
                    if let selectedIdx = tabWindows.firstIndex(of: selectedWindow) {
                        activeIndex = selectedIdx
                    }
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
        
        let sidebarActive = (Config.sharedDefaults?.integer(forKey: "leftSidebarMode") ?? 0) != 0
        
        var isFirstWindow = true
        for winState in session.windows {
            var firstWindow: NSWindow?
            let groupID = UUID().uuidString
            for (index, tabState) in winState.tabs.enumerated() {
                let tabID = tabState.tabID ?? UUID().uuidString
                restoredIDs.append(tabID)
                TabRegistry.shared.states[tabID] = tabState
                
                if isFirstWindow && index == 0 {
                    // Register the initial WindowGroup window in the group
                    if sidebarActive {
                        tabGroups[tabID] = groupID
                    }
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
                newWindow.contentView = NSHostingView(rootView: contentView.environmentObject(WindowManager.shared))
                newWindow.delegate = WindowDelegate.shared
                newWindow.identifier = NSUserInterfaceItemIdentifier(tabID)
                
                openWindows.append(newWindow)
                
                if index == 0 {
                    firstWindow = newWindow
                    if sidebarActive {
                        tabGroups[tabID] = groupID
                    }
                    newWindow.makeKeyAndOrderFront(nil)
                } else {
                    if sidebarActive {
                        tabGroups[tabID] = groupID
                        // Don't show non-active tabs
                    } else {
                        firstWindow?.addTabbedWindow(newWindow, ordered: .above)
                    }
                }
                
                if index == winState.activeTabIndex {
                    if sidebarActive {
                        // Hide other windows in this group, show this one
                        for otherWindow in openWindows {
                            if let otherID = otherWindow.identifier?.rawValue,
                               tabGroups[otherID] == groupID && otherID != tabID {
                                otherWindow.orderOut(nil)
                            }
                        }
                    }
                    newWindow.makeKeyAndOrderFront(nil)
                }
            }
            
            isFirstWindow = false
        }
        
        isRestoring = false
        return restoredIDs
    }
}
