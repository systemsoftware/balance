import Foundation
internal import Combine

enum PermissionState: String, Codable, CaseIterable {
    case ask = "Ask"
    case allow = "Allow"
    case deny = "Deny"
}

enum SettingState: String, Codable, CaseIterable {
    case allow = "Allow"
    case block = "Block"
}

enum ToggleState: String, Codable, CaseIterable {
    case enabled = "Enabled"
    case disabled = "Disabled"
}

class SitePermissionStore: ObservableObject {
    static let shared = SitePermissionStore()
    
    @Published var permissions: [String: [String: String]] = [:]
    
    private let key = "site_permissions_v1"
    
    init() {
        load()
    }
    
    private func load() {
        if let data = Config.sharedDefaults?.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            self.permissions = decoded
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(permissions) {
            Config.sharedDefaults?.set(encoded, forKey: key)
        }
    }
    
    func mediaPermission(for host: String, type: String) -> PermissionState {
        if let val = permissions[host]?[type], let state = PermissionState(rawValue: val) {
            return state
        }
        return .ask
    }
    
    func setMediaPermission(for host: String, type: String, state: PermissionState) {
        if permissions[host] == nil {
            permissions[host] = [:]
        }
        permissions[host]?[type] = state.rawValue
        save()
    }
    
    func setting(for host: String, type: String, defaultState: SettingState) -> SettingState {
        if let val = permissions[host]?[type], let state = SettingState(rawValue: val) {
            return state
        }
        return defaultState
    }
    
    func setSetting(for host: String, type: String, state: SettingState) {
        if permissions[host] == nil {
            permissions[host] = [:]
        }
        permissions[host]?[type] = state.rawValue
        save()
    }
    
    func toggleState(for host: String, type: String, defaultState: ToggleState) -> ToggleState {
        if let val = permissions[host]?[type], let state = ToggleState(rawValue: val) {
            return state
        }
        return defaultState
    }
    
    func setToggleState(for host: String, type: String, state: ToggleState) {
        if permissions[host] == nil {
            permissions[host] = [:]
        }
        permissions[host]?[type] = state.rawValue
        save()
    }
    
    func zoomLevel(for host: String) -> Int {
        if let val = permissions[host]?["zoom"], let zoom = Int(val) {
            return zoom
        }
        return (Config.sharedDefaults?.object(forKey: "defaultPageZoom") as? Int) ?? 100
    }
    
    func setZoomLevel(for host: String, value: Int) {
        if permissions[host] == nil {
            permissions[host] = [:]
        }
        permissions[host]?["zoom"] = String(value)
        save()
    }
}
