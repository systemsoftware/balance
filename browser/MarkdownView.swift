import SwiftUI

// MARK: - View

struct MarkdownView: View {

    var url: URL?

    /// Called when the user taps a link. Return `.handled` to swallow it,
    /// or `.systemAction` to let the system open it as usual.
    var onOpenLink: (URL) -> OpenURLAction.Result = { _ in .systemAction }

    /// `nil` while loading.
    @State private var blocks: [MarkdownBlock]?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let url {
                if loadFailed {
                    message("Failed to load markdown from \(url.absoluteString)", color: .red)
                } else if let blocks {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                                blockView(block)
                                    .padding(.top, spacing(at: index, in: blocks))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                } else {
                    ProgressView()
                }
            } else {
                message("No URL provided", color: .gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .environment(\.openURL, OpenURLAction { onOpenLink($0) })
        .task(id: url) { await load() }
    }

    // MARK: Rendering

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(headingFont(level))
                    .fontWeight(.bold)
                if level <= 2 { Divider() }
            }
            .padding(.top, level <= 2 ? 8 : 4)

        case .paragraph(let text):
            Text(text)

        case .bullet(let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(indent == 0 ? "•" : "◦")
                Text(text)
            }
            .padding(.leading, CGFloat(indent) * 18)

        case .numbered(let indent, let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").monospacedDigit()
                Text(text)
            }
            .padding(.leading, CGFloat(indent) * 18)

        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 3)
                Text(text)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .code(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

        case .rule:
            Divider().padding(.vertical, 4)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }

    /// Tight spacing between consecutive list items, looser everywhere else.
    private func spacing(at index: Int, in blocks: [MarkdownBlock]) -> CGFloat {
        guard index > 0 else { return 0 }
        switch (blocks[index - 1], blocks[index]) {
        case (.bullet, .bullet), (.bullet, .numbered),
             (.numbered, .bullet), (.numbered, .numbered):
            return 4
        default:
            return 12
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .foregroundStyle(color)
            .padding()
    }

    // MARK: Loading

    private func load() async {
        blocks = nil
        loadFailed = false
        guard let url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let source = String(decoding: data, as: UTF8.self)
            // baseURL lets relative links (e.g. "other.md") resolve next to the file
            blocks = MarkdownParser(baseURL: url.deletingLastPathComponent()).parse(source)
        } catch {
            if !Task.isCancelled { loadFailed = true }
        }
    }
}

// MARK: - Model

enum MarkdownBlock {
    case heading(level: Int, text: AttributedString)
    case paragraph(AttributedString)
    case bullet(indent: Int, text: AttributedString)
    case numbered(indent: Int, number: String, text: AttributedString)
    case quote(AttributedString)
    case code(String)
    case rule
}

// MARK: - Parser

/// A small line-based Markdown parser. Block elements are handled here;
/// inline formatting (bold, italic, `code`, links) is delegated to
/// `AttributedString(markdown:)`.
struct MarkdownParser {

    var baseURL: URL?

    func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var codeLines: [String] = []
        var inCode = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(inline(paragraph.joined(separator: " "))))
            paragraph = []
        }

        func flushQuote() {
            guard !quote.isEmpty else { return }
            blocks.append(.quote(inline(quote.joined(separator: " "))))
            quote = []
        }

        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if inCode {
                if trimmed.hasPrefix("```") {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    codeLines.append(rawLine)
                }
                continue
            }
            if trimmed.hasPrefix("```") {
                flushParagraph(); flushQuote()
                inCode = true
                continue
            }

            // Blank line ends paragraphs and quotes
            if trimmed.isEmpty {
                flushParagraph(); flushQuote()
                continue
            }

            // Heading
            if let (level, text) = parseHeading(trimmed) {
                flushParagraph(); flushQuote()
                blocks.append(.heading(level: level, text: inline(text)))
                continue
            }

            // Horizontal rule (checked before lists so "* * *" isn't a bullet)
            if isRule(trimmed) {
                flushParagraph(); flushQuote()
                blocks.append(.rule)
                continue
            }

            // Block quote
            if trimmed.hasPrefix(">") {
                flushParagraph()
                quote.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }
            flushQuote()

            // List item
            if let item = parseListItem(rawLine) {
                flushParagraph()
                blocks.append(item)
                continue
            }

            paragraph.append(trimmed)
        }

        flushParagraph(); flushQuote()
        if inCode { blocks.append(.code(codeLines.joined(separator: "\n"))) } // unterminated fence
        return blocks
    }

    // MARK: Helpers

    private func inline(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace),
            baseURL: baseURL
        )) ?? AttributedString(string)
    }

    private func parseHeading(_ line: String) -> (Int, String)? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        let text = line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
        return (hashes, text)
    }

    private func isRule(_ line: String) -> Bool {
        let chars = line.filter { !$0.isWhitespace }
        guard chars.count >= 3, let first = chars.first, "-*_".contains(first) else { return false }
        return chars.allSatisfy { $0 == first }
    }

    private func parseListItem(_ rawLine: String) -> MarkdownBlock? {
        let leading = rawLine.prefix(while: { $0 == " " || $0 == "\t" })
        let width = leading.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
        let indent = width / 2
        let body = rawLine.dropFirst(leading.count)

        // Bullet: "- ", "* ", "+ "
        if let marker = body.first, "-*+".contains(marker), body.dropFirst().first == " " {
            return .bullet(indent: indent, text: inline(String(body.dropFirst(2))))
        }

        // Numbered: "1. " or "1) "
        let digits = body.prefix(while: { $0.isNumber })
        if !digits.isEmpty {
            let rest = body.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return .numbered(indent: indent, number: String(digits), text: inline(String(rest.dropFirst(2))))
            }
        }
        return nil
    }
}

// Usage:
//
// MarkdownView(url: fileURL) { link in
//     if link.scheme == "myapp" {
//         router.open(link)
//         return .handled
//     }
//     return .systemAction
// }
