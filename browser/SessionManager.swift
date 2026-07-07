import Foundation
import SwiftUI

struct SessionState: Codable {
    var windows: [WindowSessionState]
    var spaceNames: [String]?
    var currentSpaceIndex: Int?
}

struct WindowSessionState: Codable {
    var windowID: String?
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
    var spaceIndex: Int?
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
        
        let sessionWindows = WindowManager.shared.browserWindows.compactMap { window -> WindowSessionState? in
            let tabStates = window.tabs.compactMap { tab in
                TabRegistry.shared.states[tab.id]
            }
            guard !tabStates.isEmpty else { return nil }
            let activeIndex = window.tabs.firstIndex(where: { $0.id == window.activeTabID }) ?? 0
            return WindowSessionState(windowID: window.id, tabs: tabStates, frameString: window.frameString, activeTabIndex: activeIndex)
        }
        
        if let data = try? JSONEncoder().encode(SessionState(
            windows: sessionWindows,
            spaceNames: WindowManager.shared.spaceNames,
            currentSpaceIndex: WindowManager.shared.currentSpaceIndex
        )) {
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
    
    func popInitialTabState() -> TabSessionState? { nil }
    
    func restoreSession(from session: SessionState) -> [String] {
        WindowManager.shared.restoreSession(session, openAdditionalWindows: true)
    }
}
