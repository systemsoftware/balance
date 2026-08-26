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
    
    static let sharedContainer: ModelContainer = {
        let schema = Schema([HistoryItem.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt or incompatible on-disk store should not prevent the browser
            // from launching. Keep history available for this session in memory.
            print("❌ Unable to open history store; using an in-memory store: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Unable to create the fallback history store: \(error)")
            }
        }
    }()
    
    static func addToHistory(title: String, url: String, profile: String = "", context: ModelContext?) {
        // 1. Check for empty data
        guard !url.isEmpty else {
            print("⚠️ History: URL was empty, skipping.")
            return
        }
        
        print("📜 Attempting to save: \(title) at \(url) for profile \(profile)")

        let searchURL = url
        let searchProfile = profile
        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.url == searchURL && $0.profile == searchProfile }
        )
        
        do {
            let existingItems = try sharedContainer.mainContext.fetch(descriptor)
            
            if let existingItem = existingItems.first {
                existingItem.timestamp = Date()
                existingItem.title = title
                print("🔄 Updated existing history item")
            } else {
                let newItem = HistoryItem(title: title, url: url, profile: profile)
                sharedContainer.mainContext.insert(newItem)
                print("✅ Inserted new history item")
            }
            
            // 2. Explicitly save to ensure persistence
            try sharedContainer.mainContext.save()
            
        } catch {
            print("❌ SwiftData Error: \(error.localizedDescription)")
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
                        
                        SearchInputView(text:$searchText)
                        
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
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
