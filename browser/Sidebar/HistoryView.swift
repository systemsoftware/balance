import SwiftUI
import SwiftData

// MARK: - 1. Model
@Model
final class HistoryItem {
    var title: String
    var url: String
    var timestamp: Date
    var profile: String = ""
    
    init(title: String, url: String, profile: String = "", timestamp: Date = Date()) {
        self.title = title
        self.url = url
        self.profile = profile
        self.timestamp = timestamp
    }
}

// MARK: - 2. Management Logic
@MainActor
class HistoryManager {
    struct Entry {
        let title: String
        let url: String
    }

    private struct PendingVisit {
        let entry: Entry
        let profile: String
    }

    private static var pendingVisits: [String: PendingVisit] = [:]
    private static var saveTask: Task<Void, Never>?
    
    static let sharedContainer: ModelContainer = {
        let schema = Schema([HistoryItem.self])
        do {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Balance", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                "History",
                schema: schema,
                url: directory.appendingPathComponent("History.store")
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("❌ Unable to open history store; using an in-memory store: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Unable to create the fallback history store: \(error)")
            }
        }
    }()
    
    static func addToHistory(title: String, url: String, profile: String = "") {
        guard !url.isEmpty else { return }
        pendingVisits["\(profile)\u{0}\(url)"] = PendingVisit(
            entry: Entry(title: title, url: url),
            profile: profile
        )
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            flushPending()
        }
    }

    static func flushPending() {
        saveTask?.cancel()
        saveTask = nil
        let visits = Array(pendingVisits.values)
        pendingVisits.removeAll(keepingCapacity: true)
        for group in Dictionary(grouping: visits, by: \.profile) {
            persist(group.value.map(\.entry), profile: group.key)
        }
    }

    /// Imports many visits with one fetch and one save instead of blocking the
    /// main context once per entry.
    static func addToHistory(_ entries: [Entry], profile: String = "") {
        persist(entries, profile: profile)
    }

    private static func persist(_ entries: [Entry], profile: String) {
        guard !entries.isEmpty else { return }
        let searchProfile = profile
        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.profile == searchProfile }
        )

        do {
            let existingItems = try sharedContainer.mainContext.fetch(descriptor)
            var itemsByURL = Dictionary(existingItems.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
            let timestamp = Date()

            for entry in entries where !entry.url.isEmpty {
                if let item = itemsByURL[entry.url] {
                    item.title = entry.title
                    item.timestamp = timestamp
                } else {
                    let item = HistoryItem(
                        title: entry.title,
                        url: entry.url,
                        profile: profile,
                        timestamp: timestamp
                    )
                    sharedContainer.mainContext.insert(item)
                    itemsByURL[entry.url] = item
                }
            }
            try sharedContainer.mainContext.save()
        } catch {
            print("❌ Failed to import history: \(error.localizedDescription)")
            sharedContainer.mainContext.rollback()
        }
    }
    
    @discardableResult
    static func clearAllHistory(profile: String = "") -> Bool {
        let searchProfile = profile
        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.profile == searchProfile }
        )
        do {
            let items = try sharedContainer.mainContext.fetch(descriptor)
            for item in items {
                sharedContainer.mainContext.delete(item)
            }
            try sharedContainer.mainContext.save()
            return true
        } catch {
            print("❌ Failed to clear history: \(error)")
            sharedContainer.mainContext.rollback()
            return false
        }
    }
    
    @discardableResult
    static func deleteHistory(matchingSite site: String) -> Bool {
        let target = site.lowercased()
        do {
            let allItems = try sharedContainer.mainContext.fetch(FetchDescriptor<HistoryItem>())
            let matches = allItems.filter { item in
                guard let host = URL(string: item.url)?.host?.lowercased() else { return false }
                return host == target || host.hasSuffix(".\(target)")
            }
            guard !matches.isEmpty else { return true }
            for item in matches {
                sharedContainer.mainContext.delete(item)
            }
            try sharedContainer.mainContext.save()
            print("🧹 Removed \(matches.count) history item(s) for \(site) across all profiles")
            return true
        } catch {
            print("❌ Failed to delete history matching \(site): \(error)")
            sharedContainer.mainContext.rollback()
            return false
        }
    }

}


// MARK: - 3. History View
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var historyItems: [HistoryItem]
    
    @State private var searchText: String = ""
    let profile: String
    
    init(profile: String = "") {
        self.profile = profile
        let searchProfile = profile
        var descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.profile == searchProfile },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        _historyItems = Query(descriptor)
    }
    
    var filteredHistory: [HistoryItem] {
        if searchText.isEmpty {
            return historyItems
        }
        
        return historyItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with "Clear All"
            HStack {
                Text("History")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Clear All") {
                    clearHistory()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()


            SearchInputView(text:$searchText)
                .padding(.horizontal)
                .padding(.bottom, 10)


            ScrollView {

                if historyItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 40))
                            .secondaryAlpha()
                        Text("No history found")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 8) {
                        
                        ForEach(filteredHistory) { item in
                            HistoryRow(item: item) {
                                createNewTab(with: URL(string:item.url))
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(item)
                                }
                                Button("Copy URL") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.url, forType: .string)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .background(Color.black.opacity(0.02))
    }

    private func clearHistory() {
        // End any row interaction before invalidating every model backing the list.
        // Deferring by one main-actor turn also lets SwiftUI dismiss a context menu.
        Task { @MainActor in
            await Task.yield()
            _ = HistoryManager.clearAllHistory(profile: profile)
        }
    }
}

// MARK: - 4. Reusable Row Component
struct HistoryRow: View {
    let item: HistoryItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    CachedAsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(item.url)"))
                        .frame(width: 16, height: 16)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title.isEmpty ? item.url : item.title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack {
                        Text(item.url)
                            .lineLimit(1)
                        Text("•")
                        Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// Helper for styling
extension View {
    func secondaryAlpha() -> some View {
        self.opacity(0.4)
    }
}
