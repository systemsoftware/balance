import SwiftUI
import Security

struct ServerTrustView: View {
    let trust: SecTrust
    
    @State private var isTrusted: Bool = false
    @State private var certificates: [SecCertificate] = []
    @State private var errorMessage: String? = nil
    
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
        .padding()
        .frame(width: 350, height: 400)
        .onAppear {
            evaluateTrust()
        }
    }
    
    private func evaluateTrust() {
        var error: CFError?
        isTrusted = SecTrustEvaluateWithError(trust, &error)
        
        if let error = error {
            errorMessage = error.localizedDescription
        }
        
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            certificates = chain
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
