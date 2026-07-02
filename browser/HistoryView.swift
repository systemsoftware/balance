import SwiftUI
import SwiftData

// MARK: - 1. Model
@Model
final class HistoryItem {
    var title: String
    var url: String
    var timestamp: Date
    
    init(title: String, url: String, timestamp: Date = Date()) {
        self.title = title
        self.url = url
        self.timestamp = timestamp
    }
}

// MARK: - 2. Management Logic
@MainActor
class HistoryManager {
    
    static let sharedContainer: ModelContainer = {
        let schema = Schema([HistoryItem.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
    
    static func addToHistory(title: String, url: String, context: ModelContext?) {
        // 1. Check for empty data
        guard !url.isEmpty else {
            print("⚠️ History: URL was empty, skipping.")
            return
        }
        
        print("📜 Attempting to save: \(title) at \(url)")

        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.url == url }
        )
        
        do {
            let existingItems = try sharedContainer.mainContext.fetch(descriptor)
            
            if let existingItem = existingItems.first {
                existingItem.timestamp = Date()
                existingItem.title = title
                print("🔄 Updated existing history item")
            } else {
                let newItem = HistoryItem(title: title, url: url)
                sharedContainer.mainContext.insert(newItem)
                print("✅ Inserted new history item")
            }
            
            // 2. Explicitly save to ensure persistence
            try sharedContainer.mainContext.save()
            
        } catch {
            print("❌ SwiftData Error: \(error.localizedDescription)")
        }
    }
    
    static func clearAllHistory() {
        sharedContainer.deleteAllData()
    }
    
}


// MARK: - 3. History View
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var historyItems: [HistoryItem]
    
    @State private var searchText: String = ""
    
    init() {
        var descriptor = FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
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
                    try? modelContext.delete(model: HistoryItem.self)
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
                }
            }
        }
        .background(Color.black.opacity(0.02))
    }
}

// MARK: - 4. Reusable Row Component
struct HistoryRow: View {
    let item: HistoryItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Circular Time Icon
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 28, height: 28)
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
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
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}

// Helper for styling
extension View {
    func secondaryAlpha() -> some View {
        self.opacity(0.4)
    }
}
