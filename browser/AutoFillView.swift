import SwiftUI

struct GoogleSuggestions: Decodable {
    let query: String
    let suggestions: [String]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        query = try container.decode(String.self)
        suggestions = try container.decode([String].self)
    }
}


struct AutoFillView: View {
    @Binding var searchTerm: String

    @State private var result: GoogleSuggestions?
    @State private var isLoading = true

    @Environment(\.dismiss) private var dismiss

    var suggestions: [String] {
        result?.suggestions ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
          

            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading suggestions…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if suggestions.isEmpty {
                    ContentUnavailableView(
                        "No Suggestions",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search.")
                    )
                } else {
                    List(suggestions, id: \.self) { suggestion in
                        Button {
                            searchTerm = suggestion
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)

                                Text(suggestion)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .listRowBackground(Color.clear)
                    .animation(.default, value: suggestions)
                }
            }
            .padding()
        }
        .task {
            isLoading = true
            defer { isLoading = false }

            result = try? await loadData()
        }
    }

    func loadData() async throws -> GoogleSuggestions? {
        guard
            let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&hl=en&q=\(encoded)")
        else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(GoogleSuggestions.self, from: data)
    }
}
