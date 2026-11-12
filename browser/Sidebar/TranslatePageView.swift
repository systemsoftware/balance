import SwiftUI
import Translation

struct TranslatePageView: View {
    @State private var text = ""
    @State private var from = ""
    @State private var to = "en"
    @State private var translatedText = ""
    @State private var isTranslating = false
    @State private var didCopy = false
    @State private var translationConfig: TranslationSession.Configuration?

    private var languages: [Locale.Language] {
        var seen = Set<String>()
        return (["en"] + Locale.preferredLanguages).compactMap { identifier in
            Locale.Language(identifier: identifier).languageCode?.identifier
        }.filter {
            seen.insert($0).inserted
        }.map(Locale.Language.init(identifier:))
    }

    private func languageName(_ identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(translatedText.isEmpty ? "Translate Text" : "Translation")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }
            .padding()

            if translatedText.isEmpty {
                inputView
            } else {
                resultView
            }
        }
    }

    // MARK: - Input (unchanged in spirit)

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isTranslating {
                ProgressView {
                    VStack {
                        Text("Translating...")
                        Button("Cancel") {
                            translationConfig = nil
                            isTranslating = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .topLeading) {
                          TextEditor(text: $text)
                        .font(.system(.body, design: .rounded))
                        .textEditorStyle(.plain)

                          if text.isEmpty {
                              Text("Enter text to translate")
                                  .foregroundColor(.secondary.opacity(0.5))
                               .padding(.top, 2)
                                  .padding(.leading, 3)
                                  .allowsHitTesting(false)
                          }
                      }
                      .background(
                          RoundedRectangle(cornerRadius: 8)
                            .background(.secondary.opacity(0.1))
                      )

                HStack {
                    Picker("From", selection: $from) {
                        Text("Auto").tag("")
                        ForEach(languages, id: \.self) { language in
                            Text(languageName(language.minimalIdentifier))
                                .tag(language.minimalIdentifier)
                        }
                    }
                    Picker("to", selection: $to) {
                        ForEach(languages, id: \.self) { language in
                            Text(languageName(language.minimalIdentifier))
                                .tag(language.minimalIdentifier)
                        }
                    }
                }

                Button {
                    isTranslating = true
                    translationConfig = TranslationSession.Configuration(
                        source: from.isEmpty ? nil : Locale.Language(identifier: from),
                        target: Locale.Language(identifier: to)
                    )
                } label: {
                    Text("Translate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || to.isEmpty)
                Spacer()
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .translationTask(translationConfig) { session in
            let response = try? await session.translate(text)
            translatedText = response?.targetText ?? ""
            isTranslating = false
        }
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Translation: the main thing on the screen
                    VStack(alignment: .leading, spacing: 10) {
                        Label(languageName(to), systemImage: "character.bubble")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tint)

                        Text(translatedText)
                            .font(.system(.title2, design: .rounded).weight(.medium))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.appAccent.opacity(0.1))
                    )

                    // Original: quieter, secondary
                    VStack(alignment: .leading, spacing: 8) {
                        Text(from.isEmpty ? "Original" : languageName(from))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }

            actionBar
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                reset()
            } label: {
                Label("New translation", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                PlatformApplication.copy(translatedText)
                didCopy = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    didCopy = false
                }
            } label: {
                Label(didCopy ? "Copied" : "Copy",
                      systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderedProminent)
            .animation(.default, value: didCopy)
        }
        .controlSize(.large)
        .padding()
     //   .background(.bar)
    }

    private func reset() {
        translatedText = ""
        text = ""
        from = ""
        to = "en"
        didCopy = false
        translationConfig = nil
    }
}
