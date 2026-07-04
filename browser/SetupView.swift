import SwiftUI
import AppKit
import SQLite3
import Security
import CommonCrypto
import SwiftData
internal import Combine

// MARK: - Browser Import Types

enum ImportBrowser: String, CaseIterable, Identifiable {
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    case firefox = "Firefox"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chrome: return "globe"
        case .edge: return "globe.americas"
        case .firefox: return "flame"
        }
    }
    
    var color: Color {
        switch self {
        case .chrome: return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .edge: return Color(red: 0.0, green: 0.47, blue: 0.84)
        case .firefox: return Color(red: 1.0, green: 0.45, blue: 0.0)
        }
    }
    
    var profilePath: String {
        // In a sandboxed app, homeDirectoryForCurrentUser returns the container.
        // Use getpwuid to get the real user home directory.
        let home: String
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            home = String(cString: dir)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser.path
        }
        switch self {
        case .chrome:
            return "\(home)/Library/Application Support/Google/Chrome/Default"
        case .edge:
            return "\(home)/Library/Application Support/Microsoft Edge/Default"
        case .firefox:
            return "\(home)/Library/Application Support/Firefox/Profiles"
        }
    }
    
    var isInstalled: Bool {
        let fm = FileManager.default
        if self == .firefox {
            // Check that the Profiles directory exists and contains at least one profile
            guard fm.fileExists(atPath: profilePath),
                  let contents = try? fm.contentsOfDirectory(atPath: profilePath),
                  !contents.isEmpty
            else { return false }
            return true
        }
        // For Chromium browsers, check that the Default profile directory exists
        return fm.fileExists(atPath: profilePath)
    }
    
    var keychainService: String {
        switch self {
        case .chrome: return "Chrome Safe Storage"
        case .edge: return "Microsoft Edge Safe Storage"
        case .firefox: return ""
        }
    }
    
    var keychainAccount: String {
        switch self {
        case .chrome: return "Chrome"
        case .edge: return "Microsoft Edge"
        case .firefox: return ""
        }
    }
}

struct ImportResult {
    var bookmarksCount: Int = 0
    var historyCount: Int = 0
    var passwordsCount: Int = 0
    var errors: [String] = []
    var completed: Bool = false
}

// MARK: - Browser Importer

class BrowserImporter: ObservableObject {
    @Published var results: [ImportBrowser: ImportResult] = [:]
    @Published var currentlyImporting: ImportBrowser?
    
    private let bookmarkStore = BookmarkStore()
    
    // MARK: - Main Import
    
    func importFrom(_ browser: ImportBrowser) {
        currentlyImporting = browser
        var result = ImportResult()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            if browser == .firefox {
                self.importFirefox(&result)
            } else {
                self.importChromium(browser, &result)
            }
            
            result.completed = true
            
            DispatchQueue.main.async {
                self.results[browser] = result
                self.currentlyImporting = nil
            }
        }
    }
    
    // MARK: - Chromium Import (Chrome & Edge)
    
    private func importChromium(_ browser: ImportBrowser, _ result: inout ImportResult) {
        let basePath = browser.profilePath
        
        // Bookmarks
        let bookmarksPath = "\(basePath)/Bookmarks"
        if FileManager.default.fileExists(atPath: bookmarksPath) {
            let bookmarks = parseChromiumBookmarks(at: bookmarksPath)
            for bm in bookmarks {
                bookmarkStore.add(bm)
            }
            result.bookmarksCount = bookmarks.count
        } else {
            result.errors.append("Bookmarks file not found")
        }
        
        // History
        let historyPath = "\(basePath)/History"
        if FileManager.default.fileExists(atPath: historyPath) {
            let entries = readChromiumHistory(at: historyPath)
            let context = HistoryManager.sharedContainer.mainContext
            for entry in entries {
                DispatchQueue.main.sync {
                    HistoryManager.addToHistory(title: entry.title, url: entry.url, context: context)
                }
            }
            result.historyCount = entries.count
        } else {
            result.errors.append("History file not found")
        }
        
        // Passwords
        let loginDataPath = "\(basePath)/Login Data"
        if FileManager.default.fileExists(atPath: loginDataPath) {
            let passwords = readChromiumPasswords(at: loginDataPath, browser: browser)
            for pw in passwords {
                DispatchQueue.main.sync {
                    PasswordManager.shared.savePassword(username: pw.username, passwordString: pw.password, domain: pw.domain)
                }
            }
            result.passwordsCount = passwords.count
        } else {
            result.errors.append("Login Data file not found")
        }
    }
    
    // MARK: Chromium Bookmarks (JSON)
    
    private func parseChromiumBookmarks(at path: String) -> [Bookmark] {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = json["roots"] as? [String: Any]
        else { return [] }
        
        var bookmarks: [Bookmark] = []
        for (_, value) in roots {
            if let node = value as? [String: Any] {
                extractBookmarks(from: node, into: &bookmarks)
            }
        }
        return bookmarks
    }
    
    private func extractBookmarks(from node: [String: Any], into bookmarks: inout [Bookmark]) {
        let type = node["type"] as? String ?? ""
        
        if type == "url", let name = node["name"] as? String, let url = node["url"] as? String {
            if !url.isEmpty && !url.hasPrefix("chrome://") && !url.hasPrefix("edge://") {
                bookmarks.append(Bookmark(title: name, url: url))
            }
        } else if type == "folder", let children = node["children"] as? [[String: Any]] {
            for child in children {
                extractBookmarks(from: child, into: &bookmarks)
            }
        }
    }
    
    // MARK: Chromium History (SQLite)
    
    private func readChromiumHistory(at path: String) -> [(title: String, url: String)] {
        // Copy file to avoid locking issues with running browser
        let tempPath = NSTemporaryDirectory() + "balance_import_history_\(UUID().uuidString)"
        try? FileManager.default.copyItem(atPath: path, toPath: tempPath)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(tempPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let query = "SELECT url, title FROM urls ORDER BY last_visit_time DESC LIMIT 500"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        
        var entries: [(title: String, url: String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let url = String(cString: sqlite3_column_text(stmt, 0))
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? url
            if !url.isEmpty && !url.hasPrefix("chrome://") && !url.hasPrefix("edge://") {
                entries.append((title: title, url: url))
            }
        }
        return entries
    }
    
    // MARK: Chromium Passwords (SQLite + Keychain)
    
    private struct ImportedPassword {
        let domain: String
        let username: String
        let password: String
    }
    
    private func readChromiumPasswords(at path: String, browser: ImportBrowser) -> [ImportedPassword] {
        // Copy file
        let tempPath = NSTemporaryDirectory() + "balance_import_logins_\(UUID().uuidString)"
        try? FileManager.default.copyItem(atPath: path, toPath: tempPath)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        
        // Get decryption key from Keychain
        let decryptionKey = getChromiumDecryptionKey(browser: browser)
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(tempPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let query = "SELECT origin_url, username_value, password_value FROM logins WHERE blacklisted_by_user = 0"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        
        var passwords: [ImportedPassword] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let originURL = String(cString: sqlite3_column_text(stmt, 0))
            let username = String(cString: sqlite3_column_text(stmt, 1))
            
            let blobLength = sqlite3_column_bytes(stmt, 2)
            var passwordString = ""
            
            if blobLength > 0, let blob = sqlite3_column_blob(stmt, 2) {
                let data = Data(bytes: blob, count: Int(blobLength))
                if let key = decryptionKey, let decrypted = decryptChromiumPassword(data, key: key) {
                    passwordString = decrypted
                }
            }
            
            // Extract domain from URL
            if let url = URL(string: originURL), let host = url.host, !username.isEmpty {
                passwords.append(ImportedPassword(domain: host, username: username, password: passwordString))
            }
        }
        return passwords
    }
    
    private func getChromiumDecryptionKey(browser: ImportBrowser) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: browser.keychainService,
            kSecAttrAccount as String: browser.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let passwordData = item as? Data else { return nil }
        
        // Derive key using PBKDF2
        let salt = "saltysalt".data(using: .utf8)!
        let iterations: UInt32 = 1003
        let keyLength = 16
        
        var derivedKey = Data(count: keyLength)
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        
        return result == kCCSuccess ? derivedKey : nil
    }
    
    private func decryptChromiumPassword(_ encryptedData: Data, key: Data) -> String? {
        guard encryptedData.count > 3 else { return nil }
        let prefix = String(data: encryptedData.prefix(3), encoding: .utf8)
        guard prefix == "v10" else { return nil }
        
        let encrypted = Data(encryptedData.dropFirst(3))
        let iv = Data(repeating: 0x20, count: 16)
        
        let bufferSize = encrypted.count + kCCBlockSizeAES128
        var decryptedData = Data(count: bufferSize)
        var decryptedLength: size_t = 0
        
        let status = encrypted.withUnsafeBytes { encryptedBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    decryptedData.withUnsafeMutableBytes { decryptedBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, key.count,
                            ivBytes.baseAddress,
                            encryptedBytes.baseAddress, encrypted.count,
                            decryptedBytes.baseAddress, bufferSize,
                            &decryptedLength
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else { return nil }
        return String(data: decryptedData.prefix(decryptedLength), encoding: .utf8)
    }
    
    // MARK: - Firefox Import
    
    private func importFirefox(_ result: inout ImportResult) {
        guard let profilePath = findFirefoxProfile() else {
            result.errors.append("No Firefox profile found")
            return
        }
        
        let placesPath = "\(profilePath)/places.sqlite"
        
        // Bookmarks
        if FileManager.default.fileExists(atPath: placesPath) {
            let bookmarks = readFirefoxBookmarks(at: placesPath)
            for bm in bookmarks {
                bookmarkStore.add(bm)
            }
            result.bookmarksCount = bookmarks.count
            
            // History
            let entries = readFirefoxHistory(at: placesPath)
            let context = HistoryManager.sharedContainer.mainContext
            for entry in entries {
                DispatchQueue.main.sync {
                    HistoryManager.addToHistory(title: entry.title, url: entry.url, context: context)
                }
            }
            result.historyCount = entries.count
        } else {
            result.errors.append("places.sqlite not found")
        }
        
        // Passwords
        let loginsPath = "\(profilePath)/logins.json"
        if FileManager.default.fileExists(atPath: loginsPath) {
            let passwords = readFirefoxPasswords(at: loginsPath)
            for pw in passwords {
                DispatchQueue.main.sync {
                    PasswordManager.shared.savePassword(username: pw.username, passwordString: pw.password, domain: pw.domain)
                }
            }
            result.passwordsCount = passwords.count
        } else {
            result.errors.append("logins.json not found")
        }
    }
    
    private func findFirefoxProfile() -> String? {
        let profilesDir = ImportBrowser.firefox.profilePath
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: profilesDir) else { return nil }
        
        // Prefer default-release, then default, then first profile
        if let defaultRelease = contents.first(where: { $0.contains(".default-release") }) {
            return "\(profilesDir)/\(defaultRelease)"
        }
        if let defaultProfile = contents.first(where: { $0.contains(".default") }) {
            return "\(profilesDir)/\(defaultProfile)"
        }
        return contents.first.map { "\(profilesDir)/\($0)" }
    }
    
    // MARK: Firefox Bookmarks (SQLite)
    
    private func readFirefoxBookmarks(at path: String) -> [Bookmark] {
        let tempPath = NSTemporaryDirectory() + "balance_import_ff_places_\(UUID().uuidString)"
        try? FileManager.default.copyItem(atPath: path, toPath: tempPath)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(tempPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let query = """
            SELECT b.title, p.url
            FROM moz_bookmarks b
            JOIN moz_places p ON b.fk = p.id
            WHERE b.type = 1 AND p.url NOT LIKE 'place:%'
            LIMIT 500
        """
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        
        var bookmarks: [Bookmark] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let title = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "Untitled"
            let url = String(cString: sqlite3_column_text(stmt, 1))
            if !url.isEmpty {
                bookmarks.append(Bookmark(title: title.isEmpty ? url : title, url: url))
            }
        }
        return bookmarks
    }
    
    // MARK: Firefox History (SQLite)
    
    private func readFirefoxHistory(at path: String) -> [(title: String, url: String)] {
        let tempPath = NSTemporaryDirectory() + "balance_import_ff_hist_\(UUID().uuidString)"
        try? FileManager.default.copyItem(atPath: path, toPath: tempPath)
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(tempPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let query = """
            SELECT p.url, p.title
            FROM moz_places p
            JOIN moz_historyvisits v ON p.id = v.place_id
            GROUP BY p.url
            ORDER BY MAX(v.visit_date) DESC
            LIMIT 500
        """
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        
        var entries: [(title: String, url: String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let url = String(cString: sqlite3_column_text(stmt, 0))
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? url
            if !url.isEmpty && !url.hasPrefix("about:") {
                entries.append((title: title.isEmpty ? url : title, url: url))
            }
        }
        return entries
    }
    
    // MARK: Firefox Passwords (logins.json — usernames only, passwords are NSS-encrypted)
    
    private func readFirefoxPasswords(at path: String) -> [ImportedPassword] {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let logins = json["logins"] as? [[String: Any]]
        else { return [] }
        
        var passwords: [ImportedPassword] = []
        for login in logins {
            guard let hostname = login["hostname"] as? String,
                  let username = login["encryptedUsername"] as? String
            else { continue }
            
            // Firefox passwords are NSS/PKCS#11 encrypted — we can only import the domain + encrypted username
            // The username field itself is encrypted too, so we store the hostname
            let domain = URL(string: hostname)?.host ?? hostname
            if !domain.isEmpty {
                // We can't decrypt Firefox passwords without NSS; import as credential placeholder
                passwords.append(ImportedPassword(
                    domain: domain,
                    username: username,
                    password: ""
                ))
            }
        }
        return passwords
    }
}

// MARK: - Setup View

struct SetupView: View {
    @State private var currentStep = 0
    @StateObject private var importer = BrowserImporter()
    
    @AppStorage("sawSetup", store: Config.sharedDefaults)
    private var sawSetup: Bool = false
    
    var onComplete: () -> Void
    
    private let totalSteps = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            Divider()
                .opacity(0.5)
            
            // Content
            Group {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    importStep
                case 2:
                    settingsStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
        }
        .frame(width: 640, height: 540)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        HStack(spacing: 32) {
            stepDot(index: 0, label: "Welcome", icon: "hand.wave")
            stepConnector(after: 0)
            stepDot(index: 1, label: "Import", icon: "square.and.arrow.down")
            stepConnector(after: 1)
            stepDot(index: 2, label: "Settings", icon: "gearshape")
        }
        .padding(.horizontal, 40)
    }
    
    private func stepDot(index: Int, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(index <= currentStep
                          ? Color.accentColor.opacity(0.15)
                          : Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .frame(width: 36, height: 36)
                
                if index < currentStep {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(index == currentStep ? Color.accentColor : .secondary)
                }
            }
            
            Text(label)
                .font(.system(size: 11, weight: index == currentStep ? .semibold : .regular, design: .rounded))
                .foregroundStyle(index == currentStep ? .primary : .secondary)
        }
    }
    
    private func stepConnector(after index: Int) -> some View {
        Rectangle()
            .fill(index < currentStep ? Color.accentColor.opacity(0.4) : Color(NSColor.separatorColor).opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: 60)
            .offset(y: -10)
    }
    
    // MARK: - Step 1: Welcome
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            
            VStack(spacing: 8) {
                Text("Welcome to Balance")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("A fast and lightweight browser built for macOS.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            
            Text("Let's get you set up in just a few steps.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(width: 180, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Step 2: Import
    
    private var importStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Import Your Data")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("Bring your bookmarks, history, and passwords from another browser.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding(.top, 20)
            
            VStack(spacing: 10) {
                ForEach(ImportBrowser.allCases) { browser in
                    importBrowserCard(browser)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            HStack {
                Button("Skip") {
                    withAnimation { currentStep = 2 }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 13, design: .rounded))
                
                Spacer()
                
                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    Text("Next")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(width: 100, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }
    
    private func importBrowserCard(_ browser: ImportBrowser) -> some View {
        let result = importer.results[browser]
        let isImporting = importer.currentlyImporting == browser
        let isCompleted = result?.completed == true
        
        return HStack(spacing: 14) {
            // Browser icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(browser.color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: browser.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(browser.color)
            }
            
            // Browser info
            VStack(alignment: .leading, spacing: 2) {
                Text(browser.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                
                if isCompleted, let result {
                    HStack(spacing: 8) {
                        if result.bookmarksCount > 0 {
                            Label("\(result.bookmarksCount) bookmarks", systemImage: "bookmark")
                        }
                        if result.historyCount > 0 {
                            Label("\(result.historyCount) history", systemImage: "clock")
                        }
                        if result.passwordsCount > 0 {
                            Label("\(result.passwordsCount) passwords", systemImage: "key")
                        }
                    }
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                } else if !browser.isInstalled {
                    Text("Not installed")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Bookmarks, history, and passwords")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Action
            if isImporting {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 70)
            } else if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                    .frame(width: 70)
            } else {
                Button("Import") {
                    importer.importFrom(browser)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!browser.isInstalled)
                .frame(width: 70)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Step 3: Settings
    
    private var settingsStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Quick Settings")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                
                Text("Customize Balance to your liking. You can always change these later.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            SettingsView(isStandalone: false, isSetup:true)
                .padding()
            
            HStack {
                Button("Back") {
                    withAnimation { currentStep = 1 }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 13, design: .rounded))
                
                Spacer()
                
                Button {
                    sawSetup = true
                    onComplete()
                } label: {
                    Text("Finish Setup")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(width: 130, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Visual Effect View (for window background)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Setup Window Manager

class SetupWindowManager {
    static let shared = SetupWindowManager()
    
    private var setupWindow: NSWindow?
    private var hiddenWindows: [NSWindow] = []
    
    func showSetupWindow() {
        guard setupWindow == nil else {
            setupWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        // Hide all existing browser windows
        hiddenWindows = []
        for window in NSApp.windows where window.isVisible {
            hiddenWindows.append(window)
            window.orderOut(nil)
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Welcome to Balance"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        let setupView = SetupView {
            DispatchQueue.main.async { [weak self] in
                self?.dismissSetupWindow()
            }
        }
        .modelContainer(HistoryManager.sharedContainer)
        
        window.contentView = NSHostingView(rootView: setupView)
        window.makeKeyAndOrderFront(nil)
        
        self.setupWindow = window
    }
    
    func dismissSetupWindow() {
        setupWindow?.close()
        setupWindow = nil
        
        // Restore hidden browser windows
        for window in hiddenWindows {
            window.makeKeyAndOrderFront(nil)
        }
        hiddenWindows = []
    }
}
