import SwiftUI
import Security

struct EmailView: View {
    let profile: String
    var home = false
    
    @StateObject private var imapClient = IMAPClient()
    
    @AppStorage("profiles", store: Config.sharedDefaults) private var profilesJSON = "[]"
    
    private var currentProfile: Profile? {
        let profiles = (try? JSONDecoder().decode([Profile].self, from: Data(profilesJSON.utf8))) ?? []
        return profiles.first { $0.id.uuidString == profile }
    }
    
    var body: some View {
        VStack {
            if home == false {
                HStack {
                    Text("Unread Emails")
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        fetchEmails()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(imapClient.isConnecting)
                }
                .padding(.horizontal)
                .padding(.top)
            }
            
            if let error = imapClient.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if imapClient.isConnecting {
                ProgressView("Connecting to IMAP...")
                    .padding()
            } else if imapClient.unreadEmails.isEmpty {
                Text("No unread emails.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(imapClient.unreadEmails) { email in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(email.subject)
                            .font(.headline)
                        HStack {
                            Text(email.from)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(email.date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Spacer()
        }
        .onAppear {
            fetchEmails()
        }
    }
    
    private func fetchEmails() {
        guard let p = currentProfile, let host = p.imapHost, let port = p.imapPort else {
            imapClient.error = "IMAP Host or Port not configured for this profile."
            return
        }
        
        print("EMAIL: \(p) | \(host) | \(port)")
        
        let domain = "balance.profile.imap.\(p.id.uuidString)"
        
        guard let cred = PasswordManager.shared.fetchCredentialDirectly(for: domain) else {
            imapClient.error = "No IMAP credentials found in Keychain for this profile."
            return
        }
        
        let email = cred.username
        let password = cred.passwordString
        
        imapClient.fetchUnread(host: host, port: port, email: email, pass: password)
    }
}
