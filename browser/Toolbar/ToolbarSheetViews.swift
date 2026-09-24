import SwiftUI
import WebKit

struct ToolbarCommandsSheet: View {
    @Binding var searchText: String
    @Binding var searchQuery: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            CommandsView(searchText: $searchText, searchQuery: $searchQuery)
            Button("Close") { dismiss() }
                .padding()
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }
}

struct ToolbarTabSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TabSearchView(isPopover: true)
            Button("Close") { dismiss() }
                .padding()
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }
}

struct ToolbarGoToSheet: View {
    @Binding var urlInput: String
    let submitURL: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            TextField("Enter URL", text: $urlInput)
                .textFieldStyle(.roundedBorder)
                .padding()
            HStack {
                Button("Cancel") { dismiss() }
                Button("Go") {
                    dismiss()
                    submitURL()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

struct ToolbarSplitURLSheet: View {
    @Binding var splitURL: String
    @State private var draftURL = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Split View URL")
                .font(.headline)
            Text("Enter the URL to show beside the current page.")
                .foregroundStyle(.secondary)
            TextField("https://example.com", text: $draftURL)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Button("Go") {
                    if !draftURL.hasPrefix("http") {
                        splitURL = "https://" + draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        splitURL = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .onAppear { draftURL = splitURL }
    }
}

struct ToolbarRenameSheet: View {
    @ObservedObject var browserState: BrowserState
    @State private var newName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            TextField("Enter new tab name:", text: $newName)
                .textFieldStyle(.roundedBorder)
                .padding()
            HStack {
                Button("Cancel") { dismiss() }
                Button("Rename") {
                    let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedName.isEmpty {
                        browserState.customTitle = nil
                        browserState.title = browserState.webView?.title ?? "Page"
                    } else {
                        browserState.customTitle = trimmedName
                        browserState.title = trimmedName
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear { newName = browserState.customTitle ?? "" }
    }
}

struct ToolbarSummarySheet: View {
    
    @ObservedObject var browserState: BrowserState
    @Binding var isSummarizing: Bool
    @State var result = ""
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            if result.isEmpty {
                ProgressView("Generating summary...")
                    .frame(width: 700, height: 400)
            } else {
                
                SummaryWindow(url: browserState.url ?? URL(string:"https://example.com")!, title:browserState.title, summary: result)
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.red)
            }
        }
            .task {
                isSummarizing = true
                defer { isSummarizing = false }
                do {
                    result = try await generatePageSummary(state: browserState)
                } catch {
                    result = error.localizedDescription
                }
            }
    }
    
}

struct WordCountView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var browserState: BrowserState
    @State var text = ""
    @State private var isLoading = true

    var body: some View {
        let analysis = WordCountAnalysis(text: text)

        return VStack {
            ScrollView {
                if !text.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Word Count")
                            .font(.headline)
                        Text("\(analysis.wordCount) words")
                            .font(.title)
                        HStack(spacing: 24) {
                            metric("Characters", value: "\(analysis.characterCount)")
                            metric("Paragraphs", value: "\(analysis.paragraphCount)")
                            metric("Sentences", value: "\(analysis.sentenceCount)")
                            metric("Average sentence length", value: String(format: "%.1f words", analysis.averageSentenceLength))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top words")
                                .font(.headline)
                            if analysis.topWords.isEmpty {
                                Text("No keywords found")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(analysis.topWords, id: \.word) { item in
                                    HStack {
                                        Text(item.word)
                                        Spacer()
                                        Text("\(item.count) · \(item.density, specifier: "%.1f")%")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text("Percentage of all words; common words excluded from the list.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack(spacing: 24) {
                            metric("Reading time", value: analysis.readingTime)
                            metric("Speaking time", value: analysis.speakingTime)
                        }
                        Text("Based on 200 words/min reading and 130 words/min speaking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        metric("Text", value:text)
                    }
                    .padding()
                } else if isLoading {
                    ProgressView("Analyzing selected text...")
                        .frame(width: 400, height: 300)
                } else {
                    Text("No text selected")
                        .frame(width: 400, height: 300)
                }
            }
            .onAppear {
                browserState.getSelectedText { selectedText in
                    DispatchQueue.main.async {
                        text = selectedText
                        isLoading = false
                    }
                }
            }
            .frame(minWidth: 380, maxWidth: 520, maxHeight: 600)
              Button("Close") { dismiss() }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3)
        }
    }
}

private struct WordCountAnalysis {
    struct Keyword {
        let word: String
        let count: Int
        let density: Double
    }

    let wordCount: Int
    let characterCount: Int
    let paragraphCount: Int
    let sentenceCount: Int
    let averageSentenceLength: Double
    let topWords: [Keyword]
    let readingTime: String
    let speakingTime: String

    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "been", "but", "by", "for", "from",
        "had", "has", "have", "he", "her", "his", "i", "in", "is", "it", "its", "me",
        "my", "not", "of", "on", "or", "our", "she", "so", "that", "the", "their",
        "them", "there", "these", "they", "this", "to", "us", "was", "we", "were",
        "what", "when", "which", "who", "will", "with", "you", "your"
    ]

    init(text: String) {
        let source = text as NSString
        var words: [String] = []
        source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: .byWords) { substring, _, _, _ in
            if let substring { words.append(substring.lowercased()) }
        }
        wordCount = words.count
        characterCount = text.count
        paragraphCount = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count

        var sentences = 0
        source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: .bySentences) { substring, _, _, _ in
            if let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sentences += 1
            }
        }
        sentenceCount = sentences
        averageSentenceLength = sentences == 0 ? 0 : Double(words.count) / Double(sentences)

        let frequencies = Dictionary(words.filter { !Self.stopWords.contains($0) }.map { ($0, 1) }, uniquingKeysWith: +)
        topWords = frequencies.map { word, count in
            Keyword(word: word, count: count, density: words.isEmpty ? 0 : Double(count) * 100 / Double(words.count))
        }
        .sorted { $0.count == $1.count ? $0.word < $1.word : $0.count > $1.count }
        .prefix(10)
        .map { $0 }

        readingTime = Self.timeDescription(wordCount: words.count, wordsPerMinute: 200)
        speakingTime = Self.timeDescription(wordCount: words.count, wordsPerMinute: 130)
    }

    private static func timeDescription(wordCount: Int, wordsPerMinute: Int) -> String {
        guard wordCount > 0 else { return "0 sec" }
        let seconds = Int(ceil(Double(wordCount) * 60 / Double(wordsPerMinute)))
        return seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min \(seconds % 60) sec"
    }
}
