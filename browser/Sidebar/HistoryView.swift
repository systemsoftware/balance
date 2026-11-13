import SwiftUI
import SwiftData
import CloudKit

// MARK: - 1. Model
@Model
final class HistoryItem {
    var title: String = ""
    var url: String = ""
    var timestamp: Date = Date()
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
    private static let syncEnabledAtLaunch = SyncOptions.shouldAttachCloudStore("syncHistory")
        && (Config.defaults.stringArray(forKey: "pendingCloudHistoryClears") ?? []).isEmpty
    
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
                url: directory.appendingPathComponent("History.store"),
                cloudKitDatabase: syncEnabledAtLaunch
                    ? .private("iCloud.com.systemsoftware.balance") : .none
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
    
    /// Clear a profile, or all profiles when `profile` is nil. Cloud cleanup is
    /// explicit so records uploaded by an older release are removed even when
    /// history sync is currently disabled on this device.
    @discardableResult
    static func clearAllHistory(profile: String? = nil) async -> Bool {
        saveTask?.cancel()
        saveTask = nil
        if let profile {
            pendingVisits = pendingVisits.filter { $0.value.profile != profile }
        } else {
            pendingVisits.removeAll()
        }

        do {
            let items = try sharedContainer.mainContext.fetch(FetchDescriptor<HistoryItem>())
            for item in items where profile == nil || item.profile == profile {
                sharedContainer.mainContext.delete(item)
            }
            try sharedContainer.mainContext.save()
        } catch {
            print("❌ Failed to clear local history: \(error)")
            sharedContainer.mainContext.rollback()
            return false
        }

        CloudHistoryCleanup.enqueue(profile: profile)
        return await CloudHistoryCleanup.retryPending()
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
    @State private var clearError = false
    let profile: String
    
    @State private var showClear = false
    @State private var clearOption: Int = 0

    @State private var clearStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var clearEndDate: Date = Date()

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
            HStack {
                Text("History")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button {
                    showClear.toggle()
                } label: {
                    Image(systemName: "trash")
                }
                .contextMenu {
                    Button("Clear All History") {
                       clearHistory()
                    }
                    Divider()
                    Button("Clear Older Than 7 Days") {
                        clearyHistoryOlderThan(days: 7)
                    }
                    Button("Clear Older Than 30 Days") {
                        clearyHistoryOlderThan(days: 30)
                    }
                    Button("Clear Older Than 90 Days") {
                        clearyHistoryOlderThan(days: 90)
                    }
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showClear) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(.red)
                                    .frame(width: 44, height: 44)
                                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Clear History")
                                        .font(.system(.title3, design: .rounded, weight: .semibold))
                                    Text("Choose which visits to remove from this profile.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("TIME RANGE")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 8) {
                                    clearOptionRow(0, title: "All history", detail: "Remove every saved visit")
                                    clearOptionRow(1, title: "Older than 7 days", detail: "Keep the past week")
                                    clearOptionRow(2, title: "Older than 30 days", detail: "Keep the past month")
                                    clearOptionRow(3, title: "Older than 90 days", detail: "Keep the past three months")
                                    clearOptionRow(4, title: "Custom range", detail: "Choose a start and end date")
                                }
                            }

                            if clearOption == 4 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("DATES TO CLEAR")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    DatePicker("From", selection: $clearStartDate, in: ...clearEndDate, displayedComponents: .date)
                                    DatePicker("Through", selection: $clearEndDate, in: clearStartDate...Date(), displayedComponents: .date)
                                }
                                .padding(16)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                            }

                            Label("Cleared visits cannot be restored.", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Spacer()
                        Button("Cancel") { showClear = false }
                            .tint(.primary)
                            .keyboardShortcut(.cancelAction)
                        Button(role: .destructive) {
                            if clearOption == 4 {
                                clearHistoryWithinDateRange(start: clearStartDate, end: clearEndDate)
                            } else {
                                switch clearOption {
                                case 0: clearHistory()
                                case 1: clearyHistoryOlderThan(days: 7)
                                case 2: clearyHistoryOlderThan(days: 30)
                                case 3: clearyHistoryOlderThan(days: 90)
                                default: break
                                }
                            }
                            showClear = false
                        } label: {
                            Text("Clear History")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(20)
                }
                .frame(minWidth: 320, idealWidth: 420, maxWidth: 460)
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
                                    PlatformApplication.copy(item.url)
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
        .alert("Cloud history could not be cleared", isPresented: $clearError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Some history could not be cleared. If iCloud is unavailable, the app will retry its deletion on the next launch.")
        }
    }

    private func clearOptionRow(_ option: Int, title: String, detail: String) -> some View {
        Button {
            clearOption = option
        } label: {
            HStack(spacing: 12) {
                Image(systemName: clearOption == option ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(clearOption == option ? Color.appAccent : Color.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                clearOption == option ? Color.appAccent.opacity(0.08) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(clearOption == option ? Color.appAccent.opacity(0.5) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(clearOption == option ? .isSelected : [])
    }

    private func clearHistory() {
          Task { @MainActor in
            await Task.yield()
            if !(await HistoryManager.clearAllHistory(profile: profile)) {
                clearError = true
            }
        }
    }

    private func clearHistoryWithinDateRange(start: Date, end: Date) {
        Task { @MainActor in
            await Task.yield()
            let firstDay = Calendar.current.startOfDay(for: start)
            let dayAfterEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) ?? end
            let itemsToDelete = historyItems.filter { $0.timestamp >= firstDay && $0.timestamp < dayAfterEnd }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to delete history within date range: \(error)")
            }
        }
    }

    private func clearyHistoryOlderThan(days: Int) {
        Task { @MainActor in
            await Task.yield()
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let itemsToDelete = historyItems.filter { $0.timestamp < cutoffDate }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to delete history older than \(days) days: \(error)")
            }
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
                        .fill(Color.appAccent.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Favicon(item.url)
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
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.platformControlBackground.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .background(Color.platformWindowBackground.opacity(0.5))
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
