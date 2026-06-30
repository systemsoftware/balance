import SwiftUI
import Security

struct ServerTrustView: View {
    let trust: SecTrust?
    let url: URL?
    
    @StateObject private var store = SitePermissionStore.shared
    @State private var isTrusted: Bool = false
    @State private var certificates: [SecCertificate] = []
    @State private var errorMessage: String? = nil
        
    var onAttemptHTTPS: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: isTrusted ? "lock.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isTrusted ? .green : .red)
                    .font(.title)
                
                VStack(alignment: .leading) {
                    Text(isTrusted ? "Connection is secure" : "Connection is not secure")
                        .font(.headline)
                    Text("Your information is \(isTrusted ? "private" : "exposed") when it is sent to this site.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let errorMessage = errorMessage, !isTrusted {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if !isTrusted {
                Button("Attempt HTTPS Upgrade") {
                    onAttemptHTTPS?()
                }
            }
            
            if !certificates.isEmpty {
                Divider()
                
                Text("Certificate Chain")
                    .font(.subheadline)
                    .bold()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<certificates.count, id: \.self) { index in
                            let cert = certificates[index]
                            CertificateRow(certificate: cert, isRoot: index == certificates.count - 1)
                        }
                    }
                }
            }
            
            if let host = url?.host {
                Divider()
                
                Text("Permissions for \(host)")
                    .font(.subheadline)
                    .bold()
                
                VStack(spacing: 12) {
                    permissionRow(title: "Camera", icon: "camera", host: host, type: "camera", isMedia: true)
                    permissionRow(title: "Microphone", icon: "mic", host: host, type: "microphone", isMedia: true)
                    permissionRow(title: "Pop-ups", icon: "macwindow.on.rectangle", host: host, type: "popups", isMedia: false, defaultState: .block)
                    permissionRow(title: "JavaScript", icon: "curlybraces.square", host: host, type: "javascript", isMedia: false, defaultState: .allow)
                }
            }
            Spacer()
        }
        .padding()
        .frame(width: 350, height: 400)
        .onAppear {
            evaluateTrust()
        }
    }
    
    private func evaluateTrust() {
        guard let trust = trust else {
            isTrusted = false
            errorMessage = "This connection is not encrypted."
            return
        }
        var error: CFError?
        isTrusted = SecTrustEvaluateWithError(trust, &error)
        
        if let error = error {
            errorMessage = error.localizedDescription
        }
        
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            certificates = chain
        }
    }
    
    @ViewBuilder
    private func permissionRow(title: String, icon: String, host: String, type: String, isMedia: Bool, defaultState: SettingState = .allow) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isMedia {
                Picker("", selection: Binding(
                    get: { store.mediaPermission(for: host, type: type) },
                    set: { store.setMediaPermission(for: host, type: type, state: $0) }
                )) {
                    ForEach(PermissionState.allCases, id: \.self) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .frame(width: 100)
                .labelsHidden()
            } else {
                Picker("", selection: Binding(
                    get: { store.setting(for: host, type: type, defaultState: defaultState) },
                    set: { store.setSetting(for: host, type: type, state: $0) }
                )) {
                    ForEach(SettingState.allCases, id: \.self) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .frame(width: 100)
                .labelsHidden()
            }
        }
    }
}

struct CertificateRow: View {
    let certificate: SecCertificate
    let isRoot: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isRoot ? "building.columns.fill" : "doc.text.fill")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(summary)
                    .font(.system(.subheadline, design: .default))
                    .bold()
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var summary: String {
        if let summaryString = SecCertificateCopySubjectSummary(certificate) as String? {
            return summaryString
        }
        return "Unknown Certificate"
    }
}
