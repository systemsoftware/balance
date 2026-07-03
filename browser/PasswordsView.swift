import SwiftUI
import AppKit
import LocalAuthentication

struct PasswordsView: View {
    @ObservedObject var passwordManager = PasswordManager.shared
    @State private var searchText = ""
    
    var filteredCredentials: [SavedCredential] {
        if searchText.isEmpty {
            return passwordManager.savedCredentials
        } else {
            return passwordManager.savedCredentials.filter {
                $0.domain.localizedCaseInsensitiveContains(searchText) ||
                $0.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Passwords")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }
            .padding()
            
            ScrollView {
                if passwordManager.savedCredentials.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.slash")
                            .font(.system(size: 40))
                            .opacity(0.4)
                        Text("No passwords found")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 8) {
                        SearchInputView(text: $searchText)
                        
                        ForEach(filteredCredentials) { cred in
                            PasswordRow(cred: cred)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.black.opacity(0.02))
    }
}

struct PasswordRow: View {
    let cred: SavedCredential
    @State private var isRevealed = false
    @State private var revealedPassword = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Circular Key Icon
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: "lock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(cred.domain)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(cred.username)
                        .lineLimit(1)
                    Text("•")
                    if isRevealed {
                        Text(revealedPassword)
                    } else {
                        Text("••••••••")
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            }
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    authenticate(reason: "authenticate to copy your password") {
                        if let pass = PasswordManager.shared.fetchPasswordData(for: cred.username, domain: cred.domain) {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)
                            pasteboard.setString(pass, forType: .string)
                            pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                                if pasteboard.string(forType: .string) == pass {
                                    pasteboard.clearContents()
                                }
                            }
                        }
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy Password")
                
                Button(action: {
                    if isRevealed {
                        isRevealed = false
                        revealedPassword = ""
                    } else {
                        authenticate(reason: "authenticate to view your password") {
                            if let pass = PasswordManager.shared.fetchPasswordData(for: cred.username, domain: cred.domain) {
                                revealedPassword = pass
                                isRevealed = true
                            }
                        }
                    }
                }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide Password" : "Reveal Password")
                
                Button(action: {
                    PasswordManager.shared.deletePassword(username: cred.username, domain: cred.domain)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete Password")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
    }
    
    private func authenticate(reason: String, completion: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        completion()
                    }
                }
            }
        } else {
            // Fallback if no auth available (e.g. no passcode set on Mac)
            completion()
        }
    }
}
