import Foundation
import Security
internal import Combine

struct SavedCredential: Identifiable, Hashable {
    var id: String { "\(domain)-\(username)" }
    let domain: String
    let username: String
}

class PasswordManager: ObservableObject {

    
    static let shared = PasswordManager()
    
    @Published var savedCredentials: [SavedCredential] = []
    
    init() {
        loadAllCredentials()
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
                        if let account = dict[kSecAttrAccount as String] as? String,
                           let genericData = dict[kSecAttrGeneric as String] as? Data,
                           let domain = String(data: genericData, encoding: .utf8) {
                            
                            credentials.append(SavedCredential(domain: domain, username: account))
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
        return savedCredentials.filter { $0.domain.lowercased() == domain.lowercased() }
    }
    
    func fetchPasswordData(for username: String, domain: String) -> String? {
        guard let domainData = domain.lowercased().data(using: .utf8) else { return nil }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: username,
            kSecAttrGeneric as String: domainData,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let passwordData = item as? Data {
            return String(data: passwordData, encoding: .utf8)
        }
        return nil
    }
    
    func savePassword(username: String, passwordString: String, domain: String) {
        guard let passwordData = passwordString.data(using: .utf8),
              let domainData = domain.lowercased().data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: username,
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
                kSecAttrAccount as String: username,
                kSecAttrGeneric as String: domainData,
                kSecValueData as String: passwordData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            print("PasswordManager: SecItemAdd status: \(addStatus)")
        } else {
            print("PasswordManager: SecItemUpdate status: \(status)")
        }
        
        loadAllCredentials()
    }
    
    func updateUsername(oldUsername: String, newUsername: String, domain: String) {
        guard let domainData = domain.lowercased().data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: oldUsername,
            kSecAttrGeneric as String: domainData
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecAttrAccount as String: newUsername
        ]
        
        SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        loadAllCredentials()
    }
    
    func deletePassword(username: String, domain: String) {
        guard let domainData = domain.lowercased().data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "BalanceBrowser",
            kSecAttrAccount as String: username,
            kSecAttrGeneric as String: domainData
        ]
        
        SecItemDelete(query as CFDictionary)
        loadAllCredentials()
    }
}
