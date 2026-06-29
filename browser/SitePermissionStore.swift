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
}
