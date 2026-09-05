import SwiftUI
internal import Combine

struct GoogleSuggestions: Decodable {
    let query: String
    let suggestions: [String]

    init(query: String, suggestions: [String]) {
        self.query = query
        self.suggestions = suggestions
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        query = try container.decode(String.self)
        suggestions = try container.decode([String].self)
    }
}


struct AutoFillView: View {
    @Binding var searchTerm: String
    
    @State private var result: GoogleSuggestions?
    @State private var isLoading = false
    
    @AppStorage("autofillEngine", store:Config.sharedDefaults) private var engine: String = "https://ac.duckduckgo.com/ac/?type=list&q="
    @AppStorage("searchURL", store:Config.sharedDefaults) private var searchEngine: String = "https://google.com/search?q="
    
    var noContentAvView = false
    
    @State private var activeQuery: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var cache: [String: [String]] = [:]
    
    var updateOther: Binding<String?>?
    var onSelection: (() -> Void)?
    
    var loadQuery: () -> Void
    
    private var suggestions: [String] {
        result?.suggestions ?? []
    }
    
    var body: some View {
        Group {
            
            Button {
                click("\(searchEngine)\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm)")
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    Text("Search for \(searchTerm)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .italic(true)
                    
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading suggestions…")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            } else if suggestions.isEmpty {
                if !noContentAvView {
                    ContentUnavailableView(
                        "No Suggestions",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .listRowBackground(Color.clear)
                } else {
                    Text("Type to get suggestions from \(engine.contains("google") ? "Google" : "DuckDuckGo")")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            } else {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                     click(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            
                            Text(suggestion)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .italic(suggestion == "Search for \(searchTerm)")
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .animation(.default, value: suggestions)
            }
        }
        .task(id: searchTerm) {
            let query = searchTerm
            activeQuery = query

            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await fetchSuggestions(for: query)
            } catch {}
        }
    }
    
    func click(_ sugg: String) {
        if let other = updateOther {
            other.wrappedValue = sugg
            searchTerm = ""
        } else {
            searchTerm = sugg
        }
        if let onSelection {
            onSelection()
        } else {
            dismiss()
        }
        
        loadQuery()
    }
    
    func loadData(for query: String) async throws -> GoogleSuggestions? {
        guard
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string:"\(engine)\(encoded)")
        else {
            return nil
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse  {
            let statusCode = httpResponse.statusCode
            print("HTTP Status Code: \(statusCode)")
        }
        
        return try JSONDecoder().decode(GoogleSuggestions.self, from: data)
        
    }
    
    func fetchSuggestions(for query: String) async {
        guard !query.isEmpty else {
            if activeQuery == query {
                result = nil
                isLoading = false
            }
            return
        }
        
        if let cached = cache[query] {
            if activeQuery == query {
                result = GoogleSuggestions(query: query, suggestions: cached)
                isLoading = false
            }
            return
        }
        
        if activeQuery == query {
            isLoading = true
        }
                
        do {
            let response = try await loadData(for: query)
            
            if !Task.isCancelled && activeQuery == query {
                result = response
                isLoading = false
                
                if let suggestions = response?.suggestions {
                    cache[query] = suggestions
                }
            }
        } catch {
            print("error:", error)
            if !Task.isCancelled && activeQuery == query {
                result = nil
                isLoading = false
            }
        }
    }
    
}
