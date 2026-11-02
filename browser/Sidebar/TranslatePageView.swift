import SwiftUI
import Translation

struct TranslatePageView: View {
    @State private var text = ""
    @State private var from = ""
    @State private var to = "en"
    @State private var translatedText = ""

    private var languages: [Locale.Language] {
        var seen = Set<String>()
        return (["en"] + Locale.preferredLanguages).compactMap { identifier in
            Locale.Language(identifier: identifier).languageCode?.identifier
        }.filter {
            seen.insert($0).inserted
        }.map(Locale.Language.init(identifier:))
    }

    @State private var translationConfig: TranslationSession.Configuration?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Translate Text")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }
            .padding()

            if translatedText.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Enter text to translate", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...10)

                    HStack {
                        Picker("From", selection: $from) {
                            Text("Auto").tag("")
                            ForEach(languages, id: \.self) { language in
                                Text(Locale.current.localizedString(forIdentifier: language.minimalIdentifier)
                                     ?? language.minimalIdentifier)
                                    .tag(language.minimalIdentifier)
                            }
                        }
                        Picker("to", selection: $to) {
                            ForEach(languages, id: \.self) { language in
                                Text(Locale.current.localizedString(forIdentifier: language.minimalIdentifier)
                                     ?? language.minimalIdentifier)
                                    .tag(language.minimalIdentifier)
                            }
                        }
                    }

                    Button("Translate") {
                        translationConfig = TranslationSession.Configuration(source: from.isEmpty ? nil : Locale.Language(identifier: from), target: Locale.Language(identifier: to))
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || to.isEmpty)
                    Spacer()
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .translationTask(translationConfig) { session in
                    let response = try? await session.translate(text)
                    translatedText = response?.targetText ?? ""
                }
            } else {
                VStack {
                    Text(translatedText)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    HStack {
                        Button("Back") {
                            translatedText = ""
                            text = ""
                            from = ""
                            to = "en"
                            translationConfig = nil
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button("Copy") {
                            PlatformApplication.copy(translatedText)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
    }
}
