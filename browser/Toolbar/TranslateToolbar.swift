import SwiftUI
import Translation
import NaturalLanguage

struct TranslateToolbar: View {
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false

    @State private var configuration: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var snapshot: BrowserState.TranslationTextSnapshot?
    @State private var translationError: String?
    @State private var showLanguagePicker = false
    @State private var languages: [Locale.Language] = []
    @State private var sourceID = ""
    @State private var targetID = ""

    private var canTranslate: Bool {
        !sourceID.isEmpty && !targetID.isEmpty &&
        Locale.Language(identifier: sourceID).languageCode != Locale.Language(identifier: targetID).languageCode
    }

    private func matchesSelectedSource(_ text: String, pageLanguageCode: String?) -> Bool {
        let selectedCode = Locale.Language(identifier: sourceID).languageCode?.identifier
        let pageCode = pageLanguageCode?.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
        let pageMatchesSource = pageCode?.caseInsensitiveCompare(selectedCode ?? "") == .orderedSame
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 else {
            return pageMatchesSource
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let detected = recognizer.dominantLanguage?.rawValue else { return pageMatchesSource }
        let confidence = recognizer.languageHypotheses(withMaximum: 1).values.first ?? 0
        if confidence < 0.6 { return pageMatchesSource }
        return detected.caseInsensitiveCompare(selectedCode ?? "") == .orderedSame
    }

    var body: some View {
        Button {
            guard !isTranslating else { return }
            translationError = nil
            Task {
                do {
                    snapshot = try await browserState.extractTextForTranslation()
                    guard let snapshot, !snapshot.texts.isEmpty else {
                        translationError = "No page text was found to translate."
                        return
                    }
                    let sample = snapshot.texts.prefix(100).joined(separator: " ").prefix(4_000)
                    let recognizer = NLLanguageRecognizer()
                    recognizer.processString(String(sample))
                    let code = snapshot.languageCode?.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
                        ?? recognizer.dominantLanguage?.rawValue
                    sourceID = code.map { Locale.Language(identifier: $0).minimalIdentifier } ?? ""
                    targetID = ""
                    showLanguagePicker = true
                } catch {
                    translationError = "Could not read page text: \(error.localizedDescription)"
                }
            }
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Translate", systemImage: "translate")
        }
        .buttonStyle(.plain)
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .disabled(isTranslating)
        .popover(isPresented: $showLanguagePicker) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Translate Page").font(.headline)
                Picker("From", selection: $sourceID) {
                    Text("Choose language").tag("")
                    ForEach(languages, id: \.self) { language in
                        Text(Locale.current.localizedString(forIdentifier: language.minimalIdentifier)
                            ?? language.minimalIdentifier)
                            .tag(language.minimalIdentifier)
                    }
                }
                Picker("To", selection: $targetID) {
                    Text("Choose language").tag("")
                    ForEach(languages, id: \.self) { language in
                        Text(Locale.current.localizedString(forIdentifier: language.minimalIdentifier)
                            ?? language.minimalIdentifier)
                            .tag(language.minimalIdentifier)
                    }
                }
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showLanguagePicker = false
                        snapshot = nil
                    }
                    Button("Translate") {
                        guard canTranslate else { return }
                        isTranslating = true
                        showLanguagePicker = false
                        configuration = TranslationSession.Configuration(
                            source: Locale.Language(identifier: sourceID),
                            target: Locale.Language(identifier: targetID)
                        )
                    }
                    .disabled(!canTranslate)
                }
            }
            .padding()
            .frame(width: 320)
            .task {
                let supported = await LanguageAvailability().supportedLanguages
                languages = Array(Dictionary(grouping: supported, by: \.minimalIdentifier).values.compactMap(\.first)).sorted {
                    let lhs = Locale.current.localizedString(forIdentifier: $0.minimalIdentifier) ?? $0.minimalIdentifier
                    let rhs = Locale.current.localizedString(forIdentifier: $1.minimalIdentifier) ?? $1.minimalIdentifier
                    return lhs.localizedStandardCompare(rhs) == .orderedAscending
                }
            }
        }
        .alert("Could Not Translate Page", isPresented: Binding(
            get: { translationError != nil },
            set: { if !$0 { translationError = nil } }
        )) {
            Button("OK", role: .cancel) { translationError = nil }
        } message: {
            Text(translationError ?? "")
        }
        .translationTask(configuration) { session in
            guard let snapshot else { return }
            defer {
                isTranslating = false
                configuration = nil
                self.snapshot = nil
            }
            do {
                var changedCount = 0
                var failedCount = 0
                var firstFailure: Error?
                let indices = snapshot.texts.indices.filter {
                    matchesSelectedSource(snapshot.texts[$0], pageLanguageCode: snapshot.languageCode)
                }
                if indices.isEmpty {
                    translationError = "No text matching the selected source language was found on this page."
                    return
                }
                for start in stride(from: 0, to: indices.count, by: 12) {
                    let group = Array(indices[start..<min(start + 12, indices.count)])
                    let requests = group.map { index in
                        TranslationSession.Request(
                            sourceText: snapshot.texts[index], clientIdentifier: String(index)
                        )
                    }
                    do {
                        let responses = try await session.translations(from: requests)
                        for response in responses {
                            guard let identifier = response.clientIdentifier,
                                  let index = Int(identifier), snapshot.texts.indices.contains(index) else { continue }
                            if try await browserState.applyTranslation(response.targetText, at: index, to: snapshot),
                               response.targetText != snapshot.texts[index] {
                                changedCount += 1
                            }
                        }
                    } catch {
                        firstFailure = firstFailure ?? error
                        // A single untranslatable fragment should not discard the rest of the page.
                        for index in group {
                            do {
                                let response = try await session.translate(snapshot.texts[index])
                                if try await browserState.applyTranslation(response.targetText, at: index, to: snapshot),
                                   response.targetText != snapshot.texts[index] {
                                    changedCount += 1
                                }
                            } catch {
                                failedCount += 1
                                firstFailure = firstFailure ?? error
                            }
                        }
                    }
                }
                if changedCount == 0 {
                    let sourceCode = session.sourceLanguage?.languageCode?.identifier ?? "unknown"
                    let targetCode = session.targetLanguage?.languageCode?.identifier ?? "unknown"
                    translationError = failedCount > 0
                        ? "Could not translate \(sourceCode) to \(targetCode): \(firstFailure?.localizedDescription ?? "Unknown error")"
                        : "Translation returned the original text or the page changed before it could be replaced."
                }
            } catch {
                translationError = "Translation failed: \(error.localizedDescription)"
            }
        }
    }
}
