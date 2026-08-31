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
            defaults.removeObject(forKey: "savedSessionState")
            return
        }
        
        let sessionWindows = WindowManager.shared.browserWindows.compactMap { window -> WindowSessionState? in
            let savedTabs = window.tabs.compactMap { tab -> (id: String, state: TabSessionState)? in
                guard let state = TabRegistry.shared.states[tab.id] else { return nil }
                // Private browsing state must never be written to persistent defaults.
                guard !state.isPrivate else { return nil }
                return (tab.id, state)
            }
            guard !savedTabs.isEmpty else { return nil }
            let activeIndex = savedTabs.firstIndex(where: { $0.id == window.activeTabID }) ?? 0
            return WindowSessionState(
                windowID: window.id,
                tabs: savedTabs.map(\.state),
                frameString: window.frameString,
                activeTabIndex: activeIndex
            )
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
              let session = try? JSONDecoder().decode(SessionState.self, from: data) else {
            return nil
        }

        // Older releases persisted private tabs. Remove them before restoring and
        // immediately rewrite the saved session so those URLs are scrubbed from disk.
        let privateTabIDs = session.windows
            .flatMap(\.tabs)
            .filter(\.isPrivate)
            .compactMap(\.tabID)
        for tabID in privateTabIDs {
            defaults.removeObject(forKey: "note_\(tabID)")
        }

        let sanitizedWindows = session.windows.compactMap { window -> WindowSessionState? in
            let retainedTabs = window.tabs.enumerated().filter { !$0.element.isPrivate }
            guard !retainedTabs.isEmpty else { return nil }

            var sanitizedWindow = window
            sanitizedWindow.tabs = retainedTabs.map(\.element)
            sanitizedWindow.activeTabIndex = retainedTabs.firstIndex {
                $0.offset == window.activeTabIndex
            } ?? 0
            return sanitizedWindow
        }
        guard !sanitizedWindows.isEmpty else {
            defaults.removeObject(forKey: "savedSessionState")
            return nil
        }

        let sanitizedSession = SessionState(
            windows: sanitizedWindows,
            spaceNames: session.spaceNames,
            currentSpaceIndex: session.currentSpaceIndex
        )
        if !privateTabIDs.isEmpty,
           let sanitizedData = try? JSONEncoder().encode(sanitizedSession) {
            defaults.set(sanitizedData, forKey: "savedSessionState")
        }
        return sanitizedSession
    }
    
    func popInitialTabState() -> TabSessionState? { nil }
    
    func restoreSession(from session: SessionState) -> [String] {
        WindowManager.shared.restoreSession(session, openAdditionalWindows: true)
    }
}
