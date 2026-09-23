import Foundation
import SwiftUI
import SwiftData

@Model
final class EngineItem {
    var title: String = ""
    var url: String = ""
    
    init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}

@MainActor
class EngineManager {
  

    private static var saveTask: Task<Void, Never>?
    
    static let sharedContainer: ModelContainer = {
        let schema = Schema([EngineItem.self])
        do {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Balance", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                "Engines",
                schema: schema,
                url: directory.appendingPathComponent("Engines.store"),
                cloudKitDatabase: .private("iCloud.com.systemsoftware.balance")
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("❌ Unable to open engines store; using an in-memory store: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Unable to create the fallback engines store: \(error)")
            }
        }
    }()
    
    static func add(title: String, url: String) {
        let item = EngineItem(title: title, url: url)
        sharedContainer.mainContext.insert(item)
        save()
    }
    
    static func save() {
        saveTask?.cancel()
        saveTask = Task {
            do {
                try sharedContainer.mainContext.save()
            } catch {
                print("❌ Failed to save engine store: \(error)")
            }
        }
    }
    
    static func remove(item: EngineItem) {
        sharedContainer.mainContext.delete(item)
        save()
    }

    static func update(item: EngineItem, title: String, url: String) {
        item.title = title
        item.url = url
        save()
    }

    /// Resolves an OpenSearch URL template for a query. Existing prefix-style
    /// engine URLs remain supported for backwards compatibility.
    static func searchURL(for item: EngineItem, query: String) -> URL? {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(
            CharacterSet(charactersIn: "&=+#")
        )
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }

        var template = item.url
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")

        let language = Locale.current.language.languageCode?.identifier ?? "*"
        let replacements = [
            "{searchTerms}": encodedQuery,
            "{searchTerms?}": encodedQuery,
            "{language}": language,
            "{language?}": language,
            "{inputEncoding}": "UTF-8",
            "{inputEncoding?}": "UTF-8",
            "{outputEncoding}": "UTF-8",
            "{outputEncoding?}": "UTF-8",
            "{startIndex}": "1",
            "{startIndex?}": "1",
            "{startPage}": "1",
            "{startPage?}": "1",
            "{count}": "20",
            "{count?}": "20"
        ]

        let lowercaseTemplate = template.lowercased()
        let usesOpenSearchTemplate = lowercaseTemplate.contains("{searchterms}")
            || lowercaseTemplate.contains("{searchterms?}")
            || lowercaseTemplate.contains("%7bsearchterms%7d")
            || lowercaseTemplate.contains("%7bsearchterms%3f%7d")

        if usesOpenSearchTemplate {
            for (parameter, value) in replacements {
                template = template.replacingOccurrences(
                    of: parameter,
                    with: value,
                    options: .caseInsensitive
                )
            }
            template = template.replacingOccurrences(
                of: "%7BsearchTerms%7D",
                with: encodedQuery,
                options: .caseInsensitive
            )
            template = template.replacingOccurrences(
                of: "%7BsearchTerms%3F%7D",
                with: encodedQuery,
                options: .caseInsensitive
            )
        } else if template.contains("%s") {
            template = template.replacingOccurrences(of: "%s", with: encodedQuery)
        } else {
            template += encodedQuery
        }

        return URL(string: template)
    }
    
    static func searchByName(_ name: String) -> EngineItem? {
        var descriptor = FetchDescriptor<EngineItem>(
            predicate: #Predicate { $0.title.localizedStandardContains(name)},
            sortBy: [SortDescriptor(\EngineItem.title)]
        )
        descriptor.fetchLimit = 1
        do {
            let results = try sharedContainer.mainContext.fetch(descriptor)
            return results.first
        } catch {
            print("❌ Failed to search engines by name: \(error)")
            return nil
        }
    }
   
}

struct EngineManagerView: View {
    @Binding var showingNewEngine: Bool
    var body: some View {
        EngineManagerContentView(showingNewEngine: $showingNewEngine)
            .modelContainer(EngineManager.sharedContainer)
    }
}

private struct EngineManagerContentView: View {
    @Query(sort: \EngineItem.title) private var engines: [EngineItem]
    @Binding var showingNewEngine: Bool
    @State private var editingEngine: EngineItem?
    @State private var engineToDelete: EngineItem?

    var body: some View {
        VStack(spacing: 0) {
          
            

            if engines.isEmpty {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary.opacity(0.4))

                    Text("No Engines Yet")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Button("Add") {
                        showingNewEngine = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(engines) { engine in
                            engineRow(engine)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .background(Color.black.opacity(0.03))
        .sheet(isPresented: $showingNewEngine) {
            EngineEditorView { title, url in
                EngineManager.add(title: title, url: url)
            }
        }
        .sheet(item: $editingEngine) { engine in
            EngineEditorView(
                title: engine.title,
                url: engine.url,
                isEditing: true
            ) { title, url in
                EngineManager.update(item: engine, title: title, url: url)
            }
        }
        .confirmationDialog(
            "Delete Search Engine?",
            isPresented: Binding(
                get: { engineToDelete != nil },
                set: { if !$0 { engineToDelete = nil } }
            ),
            presenting: engineToDelete
        ) { engine in
            Button("Delete \(engine.title)", role: .destructive) {
                EngineManager.remove(item: engine)
                engineToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                engineToDelete = nil
            }
        } message: { engine in
            Text("This will remove \(engine.title) from your custom search engines.")
        }
    }

    private func engineRow(_ engine: EngineItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Favicon(engine.url)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(engine.title)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(engine.url)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                editingEngine = engine
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Edit Search Engine")

            Button {
                engineToDelete = engine
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.8))
            .help("Delete Search Engine")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.platformControlBackground.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .contextMenu {
            Button {
                editingEngine = engine
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                engineToDelete = engine
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct EngineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var url: String

    let isEditing: Bool
    let onSave: (String, String) -> Void

    init(
        title: String = "",
        url: String = "",
        isEditing: Bool = false,
        onSave: @escaping (String, String) -> Void
    ) {
        _title = State(initialValue: title)
        _url = State(initialValue: url)
        self.isEditing = isEditing
        self.onSave = onSave
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var trimmedURL: String {
        if url.hasPrefix("http") {
            url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } else {
            "https://\(url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !trimmedURL.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Search Engine" : "New Search Engine")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
               
                HStack {
                    Text("@")
                    TextField("prefix", text: $title)
                        .textFieldStyle(.roundedBorder)
                        
                }
                
                Text("Type @\(trimmedTitle) <query> in the address bar to search with this engine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Search URL template", text: $url)
                    .textFieldStyle(.roundedBorder)

                Text("Use the OpenSearch placeholder {searchTerms}. Example: https://example.com/search?q={searchTerms}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save Changes" : "Add Engine") {
                    onSave(trimmedTitle, trimmedURL)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding()
        .frame(width: 380)
    }
}
