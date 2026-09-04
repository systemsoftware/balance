import Foundation
import Security
internal import Combine

struct SavedCredential: Identifiable, Hashable {
    var id: String { "\(domain)-\(username)" }
    let domain: String
    let username: String
}

struct PasswordImport: Sendable {
    let domain: String
    let username: String
    let password: String
}

class PasswordManager: ObservableObject {

    
    static let shared = PasswordManager()
    
    @Published var savedCredentials: [SavedCredential] = []
    
    init() {}
    
    func clearCredentials() {
        savedCredentials = []
    }
    
    func loadAllCredentials() {
        DispatchQueue.global(qos: .userInitiated).async {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "BalanceBrowser",
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true
            ]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            var credentials: [SavedCredential] = []
            
            if status == errSecSuccess {
                if let items = item as? [[String: Any]] {
                    for dict in items {
                        if let accountStr = dict[kSecAttrAccount as String] as? String,
                           let genericData = dict[kSecAttrGeneric as String] as? Data,
                           let domain = String(data: genericData, encoding: .utf8) {
                            
                            let username = accountStr.components(separatedBy: "::").last ?? accountStr
                            credentials.append(SavedCredential(domain: domain, username: username))
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.savedCredentials = credentials.sorted(by: { $0.domain < $1.domain })
            }
        }
    }
    
    func credentials(for domain: String) -> [SavedCredential] {
        let normalizedDomain = domain.lowercased()
        guard let domainData = normalizedDomain.data(using: .utf8) else { return [] }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrGeneric as String: domainData,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
            return []
        }

        let items: [[String: Any]]
        if let matchingItems = item as? [[String: Any]] {
            items = matchingItems
        } else if let matchingItem = item as? [String: Any] {
            items = [matchingItem]
        } else {
            return []
        }

        return items.compactMap { attributes in
            guard let account = attributes[kSecAttrAccount as String] as? String else { return nil }
            let username = account.components(separatedBy: "::").last ?? account
            return SavedCredential(domain: normalizedDomain, username: username)
        }
    }
    
    func fetchCredentialDirectly(for domain: String) -> (username: String, passwordString: String)? {
        guard let domainData = domain.lowercased().data(using: .utf8) else { return nil }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrGeneric as String: domainData,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let dict = item as? [String: Any],
           let accountStr = dict[kSecAttrAccount as String] as? String,
           let passwordData = dict[kSecValueData as String] as? Data,
           let password = String(data: passwordData, encoding: .utf8) {
            let account = accountStr.components(separatedBy: "::").last ?? accountStr
            return (account, password)
        }
        return nil
    }
    
    func fetchPasswordData(for username: String, domain: String) -> String? {
        guard let domainData = domain.lowercased().data(using: .utf8) else { return nil }
        
        let accountStr = "\(domain.lowercased())::\(username)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: accountStr,
            kSecAttrGeneric as String: domainData,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let passwordData = item as? Data {
            return String(data: passwordData, encoding: .utf8)
        }
        return nil
    }
    
    func savePassword(username: String, passwordString: String, domain: String) {
        Self.persistPassword(username: username, passwordString: passwordString, domain: domain)
        loadAllCredentials()
    }

    func savePasswords(_ passwords: [PasswordImport]) {
        guard !passwords.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            for password in passwords {
                Self.persistPassword(
                    username: password.username,
                    passwordString: password.password,
                    domain: password.domain
                )
            }
            self.loadAllCredentials()
        }
    }

    nonisolated private static func persistPassword(username: String, passwordString: String, domain: String) {
        guard let passwordData = passwordString.data(using: .utf8),
              let domainData = domain.lowercased().data(using: .utf8) else { return }
        
        let accountStr = "\(domain.lowercased())::\(username)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: accountStr,
            kSecAttrGeneric as String: domainData
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        if status == errSecItemNotFound {
            let newItem: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "BalanceBrowser",
                kSecAttrAccount as String: accountStr,
                kSecAttrGeneric as String: domainData,
                kSecValueData as String: passwordData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            print("PasswordManager: SecItemAdd status: \(addStatus)")
        } else {
            print("PasswordManager: SecItemUpdate status: \(status)")
        }
        
    }
    
    func updateUsername(oldUsername: String, newUsername: String, domain: String) {
        guard let domainData = domain.lowercased().data(using: .utf8) else { return }
        
        let oldAccountStr = "\(domain.lowercased())::\(oldUsername)"
        let newAccountStr = "\(domain.lowercased())::\(newUsername)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: oldAccountStr,
            kSecAttrGeneric as String: domainData
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecAttrAccount as String: newAccountStr
        ]
        
        SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        loadAllCredentials()
    }
    
    func deletePassword(username: String, domain: String) {
        guard let domainData = domain.lowercased().data(using: .utf8) else { return }
        
        let accountStr = "\(domain.lowercased())::\(username)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: accountStr,
            kSecAttrGeneric as String: domainData
        ]
        
        SecItemDelete(query as CFDictionary)
        loadAllCredentials()
    }
}
