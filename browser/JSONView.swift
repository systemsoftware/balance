import SwiftUI

struct JSONView: View {
    let url: URL

    @State private var json = ""
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                ContentUnavailableView(
                    "Couldn't Load JSON",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ScrollView([.horizontal, .vertical]) {
                    highlightedJSON
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .background(.background)
        .task(id: url) {
            await loadJSON()
        }
    }

    private var highlightedJSON: Text {
        JSONHighlighter.highlight(json)
    }

    @MainActor
    private func loadJSON() async {
        isLoading = true
        error = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let response = response as? HTTPURLResponse,
               !(200...299).contains(response.statusCode) {
                throw URLError(.badServerResponse)
            }

            let object = try JSONSerialization.jsonObject(with: data)

            let prettyData = try JSONSerialization.data(
                withJSONObject: object,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes
                ]
            )

            guard let string = String(data: prettyData, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }

            json = string
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

private enum JSONHighlighter {
    static func highlight(_ json: String) -> Text {
        var attributed = AttributedString()
        let characters = Array(json)
        var i = 0

        while i < characters.count {
            let char = characters[i]

            if char == "\"" {
                let start = i
                i += 1

                var escaped = false

                while i < characters.count {
                    let current = characters[i]

                    if current == "\"" && !escaped {
                        i += 1
                        break
                    }

                    if current == "\\" && !escaped {
                        escaped = true
                    } else {
                        escaped = false
                    }

                    i += 1
                }

                let value = String(characters[start..<i])

                var lookahead = i
                while lookahead < characters.count,
                      characters[lookahead].isWhitespace {
                    lookahead += 1
                }

                let isKey =
                    lookahead < characters.count &&
                    characters[lookahead] == ":"

                var chunk = AttributedString(value)
                chunk.foregroundColor = isKey ? .blue : .green

                attributed.append(chunk)
                continue
            }

            if char.isNumber || char == "-" {
                let start = i
                i += 1

                while i < characters.count {
                    let current = characters[i]

                    if current.isNumber ||
                        current == "." ||
                        current == "e" ||
                        current == "E" ||
                        current == "+" ||
                        current == "-" {
                        i += 1
                    } else {
                        break
                    }
                }

                var chunk = AttributedString(
                    String(characters[start..<i])
                )
                chunk.foregroundColor = .orange

                attributed.append(chunk)
                continue
            }

            if matches("true", at: i, in: characters) {
                var chunk = AttributedString("true")
                chunk.foregroundColor = .purple
                attributed.append(chunk)

                i += 4
                continue
            }

            if matches("false", at: i, in: characters) {
                var chunk = AttributedString("false")
                chunk.foregroundColor = .purple
                attributed.append(chunk)

                i += 5
                continue
            }

            if matches("null", at: i, in: characters) {
                var chunk = AttributedString("null")
                chunk.foregroundColor = .secondary
                attributed.append(chunk)

                i += 4
                continue
            }

            var chunk = AttributedString(String(char))
            chunk.foregroundColor = .primary
            attributed.append(chunk)

            i += 1
        }

        return Text(attributed)
    }

    private static func matches(
        _ string: String,
        at index: Int,
        in characters: [Character]
    ) -> Bool {
        let target = Array(string)

        guard index + target.count <= characters.count else {
            return false
        }

        for offset in target.indices {
            if characters[index + offset] != target[offset] {
                return false
            }
        }

        return true
    }
}
