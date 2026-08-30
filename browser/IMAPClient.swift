import Foundation
import Network
internal import Combine
import SwiftUI

struct EmailMessage: Identifiable, Hashable {
    var id: String { String(uid) }
    let uid: Int
    let subject: String
    let from: String
    let date: String
}

class IMAPClient: ObservableObject {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.balance.imap")
    
    @Published var unreadEmails: [EmailMessage] = []
    @Published var isConnecting = false
    @Published var error: String? = nil
    
    private var buffer = Data()
    private var tagCounter = 1
    
    enum IMAPError: LocalizedError {
        case connectionFailed
        case timeout
        case invalidResponse(String)
        case disconnected
        
        var errorDescription: String? {
            switch self {
            case .connectionFailed: return "Connection failed"
            case .timeout: return "Connection timed out"
            case .invalidResponse(let msg): return "Server error: \(msg)"
            case .disconnected: return "Disconnected from server"
            }
        }
    }
    
    func nextTag() -> String {
        let tag = "A\(tagCounter)"
        tagCounter += 1
        return tag
    }
    
    func fetchUnread(host: String, port: UInt16, email: String, pass: String) {
        guard !isConnecting else { return }
        isConnecting = true
        error = nil
        unreadEmails = []
        
        Task {
            do {
                try await connect(host: host, port: port)
                try await sendCommand(command: "LOGIN \"\(email)\" \"\(pass)\"")
                try await sendCommand(command: "SELECT INBOX")
                let searchResponse = try await sendCommand(command: "SEARCH UNSEEN")
                
                // Parse search response for message sequence numbers
                let uids = parseSearchResponse(searchResponse)
                
                var emails: [EmailMessage] = []
                for uid in uids.suffix(20) { // Limit to 20 latest unread
                    let fetchResponse = try await sendCommand(command: "FETCH \(uid) (BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE)])")
                    if let email = parseFetchResponse(uid: uid, response: fetchResponse) {
                        emails.append(email)
                    }
                }
                
                _ = try? await sendCommand(command: "LOGOUT")
                disconnect()
                
                await MainActor.run {
                    self.unreadEmails = emails.reversed()
                    self.isConnecting = false
                }
                
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isConnecting = false
                }
                disconnect()
            }
        }
    }
    
    private func connect(host: String, port: UInt16) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
            
            let tlsOptions = NWProtocolTLS.Options()
            let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
            
            let conn = NWConnection(to: endpoint, using: parameters)
            self.connection = conn
            
            final class ContinuationWrapper: @unchecked Sendable {
                var c: CheckedContinuation<Void, Error>?
                let lock = NSLock()
                init(_ c: CheckedContinuation<Void, Error>) { self.c = c }
                @discardableResult func resume() -> Bool {
                    lock.lock(); defer { lock.unlock() }
                    guard let c else { return false }
                    self.c = nil; c.resume(); return true
                }
                @discardableResult func resume(throwing error: Error) -> Bool {
                    lock.lock(); defer { lock.unlock() }
                    guard let c else { return false }
                    self.c = nil; c.resume(throwing: error); return true
                }
            }
            let wrapper = ContinuationWrapper(continuation)
            
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Task {
                        do {
                            _ = try await self.receiveResponse()
                            wrapper.resume()
                        } catch {
                            wrapper.resume(throwing: error)
                        }
                    }
                case .failed(let error):
                    wrapper.resume(throwing: error)
                case .cancelled:
                    wrapper.resume(throwing: IMAPError.disconnected)
                case .waiting(let error):
                    wrapper.resume(throwing: error)
                default:
                    break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 15) {
                if wrapper.resume(throwing: IMAPError.timeout) {
                    conn.cancel()
                }
            }
        }
    }
    
    private func disconnect() {
        connection?.cancel()
        connection = nil
        buffer.removeAll()
    }
    
    @discardableResult
    private func sendCommand(command: String) async throws -> String {
        let tag = nextTag()
        let fullCommand = "\(tag) \(command)\r\n"
        
        guard let conn = connection else {
            throw IMAPError.disconnected
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            final class SendWrapper: @unchecked Sendable {
                var continuation: CheckedContinuation<Void, Error>?
                let lock = NSLock()
                init(_ continuation: CheckedContinuation<Void, Error>) { self.continuation = continuation }
                @discardableResult func resume(_ error: Error? = nil) -> Bool {
                    lock.lock(); defer { lock.unlock() }
                    guard let continuation else { return false }
                    self.continuation = nil
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    return true
                }
            }
            let wrapper = SendWrapper(continuation)
            conn.send(content: fullCommand.data(using: .utf8), completion: .contentProcessed({ error in
                wrapper.resume(error)
            }))
            queue.asyncAfter(deadline: .now() + 15) {
                if wrapper.resume(IMAPError.timeout) { conn.cancel() }
            }
        }
        
        let response = try await receiveUntilTag(tag: tag)
        if response.contains("\(tag) OK") {
            return response
        } else {
            throw IMAPError.invalidResponse(response.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    private func receiveUntilTag(tag: String) async throws -> String {
        var accumulated = ""
        while true {
            let response = try await receiveResponse()
            accumulated += response
            if accumulated.contains("\(tag) OK") || accumulated.contains("\(tag) NO") || accumulated.contains("\(tag) BAD") {
                return accumulated
            }
        }
    }
    
    private func receiveResponse() async throws -> String {
        guard let conn = connection else {
            throw IMAPError.disconnected
        }
        
        while true {
            let result: String? = try await withCheckedThrowingContinuation { continuation in
                final class ReceiveWrapper: @unchecked Sendable {
                    var continuation: CheckedContinuation<String?, Error>?
                    let lock = NSLock()
                    init(_ continuation: CheckedContinuation<String?, Error>) { self.continuation = continuation }
                    @discardableResult func resume(returning value: String? = nil, throwing error: Error? = nil) -> Bool {
                        lock.lock(); defer { lock.unlock() }
                        guard let continuation else { return false }
                        self.continuation = nil
                        if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: value) }
                        return true
                    }
                }
                let wrapper = ReceiveWrapper(continuation)
                conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                    if let error = error {
                        wrapper.resume(throwing: error)
                        return
                    }
                    if let data = data {
                        let str = String(data: data, encoding: .utf8) ?? ""
                        wrapper.resume(returning: str)
                    } else if isComplete {
                        wrapper.resume(throwing: IMAPError.disconnected)
                    } else {
                        wrapper.resume()
                    }
                }
                queue.asyncAfter(deadline: .now() + 15) {
                    if wrapper.resume(throwing: IMAPError.timeout) { conn.cancel() }
                }
            }
            if let result = result {
                return result
            }
        }
    }
    
    private func parseSearchResponse(_ response: String) -> [Int] {
        var uids: [Int] = []
        let lines = response.components(separatedBy: "\r\n")
        for line in lines {
            if line.uppercased().hasPrefix("* SEARCH") {
                let parts = line.components(separatedBy: " ").dropFirst(2)
                uids.append(contentsOf: parts.compactMap { Int($0) })
            }
        }
        return uids
    }
    
    private func formatLocalizedDate(_ dateString: String) -> String {
        var cleaned = dateString
        if let regex = try? NSRegularExpression(pattern: "\\s*\\(.*?\\)\\s*$") {
            cleaned = regex.stringByReplacingMatches(in: dateString, range: NSRange(dateString.startIndex..., in: dateString), withTemplate: "")
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss zzz",
            "d MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yy HH:mm:ss Z"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                let localFormatter = DateFormatter()
                localFormatter.dateStyle = .medium
                localFormatter.timeStyle = .short
                return localFormatter.string(from: date)
            }
        }
        return dateString
    }

    private func parseFetchResponse(uid: Int, response: String) -> EmailMessage? {
        let lines = response.components(separatedBy: "\r\n")
        var subject = "No Subject"
        var from = "Unknown"
        var date = ""
        
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("subject:") {
                subject = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if lower.hasPrefix("from:") {
                from = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if lower.hasPrefix("date:") {
                let rawDate = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                date = formatLocalizedDate(rawDate)
            }
        }
        
        return EmailMessage(uid: uid, subject: subject, from: from, date: date)
    }
}
