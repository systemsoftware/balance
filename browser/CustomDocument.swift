import SwiftUI
internal import UniformTypeIdentifiers

extension UTType {
    static let bpage = UTType(exportedAs: "bryce.balance.bpage")
}

struct CustomDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.bpage] }
    
    var content: String

    init(content: String = "") {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(content.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
