import SwiftUI
import WebKit
import SwiftData
internal import Combine

let commonDataTypes: [String] = [
    WKWebsiteDataTypeDiskCache,
    WKWebsiteDataTypeMemoryCache,
    WKWebsiteDataTypeCookies,
    WKWebsiteDataTypeLocalStorage,
    WKWebsiteDataTypeSessionStorage,
    WKWebsiteDataTypeIndexedDBDatabases,
    WKWebsiteDataTypeWebSQLDatabases,
    WKWebsiteDataTypeOfflineWebApplicationCache,
    WKWebsiteDataTypeFetchCache, // iOS 16.0+
    WKWebsiteDataTypeServiceWorkerRegistrations, // iOS 16.0+
    WKWebsiteDataTypeFileSystem // iOS 17.0+
]

// MARK: - 3. History View
struct WebDataView: View {
    
    @State private var items: [WKWebsiteDataRecord] = []
        
    @State private var searchText: String = ""
    let profile: String

    @State var confirmDeleteAll = false
    @State var confirmDeleteEverything = false
        
    var store: WKWebsiteDataStore? = nil
            
    init(profile: String = "") {
        self.profile = profile
            
        if let uuid = UUID(uuidString: profile) {
            store = WKWebsiteDataStore(forIdentifier: uuid)
        } else {
            store = WKWebsiteDataStore.default()
        }
    }
    
    @MainActor
    private func loadData() async {
        print("profile: \(profile), store: \(String(describing: store))")
        guard let store = store else { return }
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        self.items = records.sorted { $0.displayName < $1.displayName }
    }
    
    var filtered: [WKWebsiteDataRecord] {
        if searchText.isEmpty {
            return items
        }
        
        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Website Data")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Delete All") {
                    confirmDeleteAll.toggle()
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


                if filtered.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "externaldrive.badge.questionmark")
                            .font(.system(size: 40))
                            .secondaryAlpha()
                        Text("No data found")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 8) {
                        
                        
                        ForEach(filtered, id:\.self) { item in
                            WebDataRow(item: item, store:store, reload:loadData, profile: profile)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .background(Color.black.opacity(0.02))
        .sheet(isPresented: $confirmDeleteEverything) {
            VStack {
                Text("Are you sure you want to delete all website data?")
                    .font(.headline)
                    .padding()
                Button(role: .destructive) {
                    clearData()
                    confirmDeleteEverything = false
                } label: {
                    Text("Delete Everything")
                        .frame(maxWidth:.infinity)
                }
                .foregroundStyle(.red)
                Button(role:.cancel) {
                    confirmDeleteEverything = false
                } label: {
                    Text("Cancel")
                        .frame(maxWidth:.infinity)
                }
            }
            .padding()
        }
        .sheet(isPresented:$confirmDeleteAll) {
            VStack{
                Text("Delete all website data for this profile?")
                    .font(.headline)
                
                ForEach(commonDataTypes, id:\.self) { type in
                    
                    let rawTitle = type.replacingOccurrences(of: "WKWebsiteDataType", with: "")

                    let title = rawTitle.replacingOccurrences(
                        of: "([a-z])([A-Z])",
                        with: "$1 $2",
                        options: .regularExpression
                    )
                    
                    HStack {
                        Text(title)
                            .font(.subheadline)
                        Spacer()
                        Button(role: .destructive) {
                            Task { @MainActor in
                                if let store = store {
                                    await store.removeData(ofTypes: [type], for: items)
                                    await loadData()
                                }
                            }
                        } label: {
                            Text("Delete")
                        }
                        .foregroundStyle(type.contains("Cache") ? .yellow : .red)
                    }
                }
                
                Button {
                    Task {
                        if let store = store {
                            await store.removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache, WKWebsiteDataTypeServiceWorkerRegistrations], modifiedSince: Date.distantPast)
                            
                                if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                                    let webKitCache = cacheURL.appendingPathComponent("WebKit")
                                    try? FileManager.default.removeItem(at: webKitCache)
                                }
                                URLCache.shared.removeAllCachedResponses()
                        }
                        confirmDeleteAll = false
                    }
                } label: {
                    Text("Delete Cache")
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.yellow)

                Button {
                    confirmDeleteAll = false
                    confirmDeleteEverything = true
                } label: {
                    Text("Delete Everything")
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.red)
                
                Button(role:.cancel) {
                    confirmDeleteAll = false
                } label: {
                    Text("Cancel")
                        .frame(maxWidth:.infinity)
                }
            }
            .padding(20)
            .presentationSizing(.fitted)
        }
        .onAppear {
            Task { await loadData() }
        }
    }

    private func clearData() {
        Task { @MainActor in
            await Task.yield()
            guard let store = store else { return }
            await store.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                for: items
            )
            print("Cleared all data.")
            await loadData()
            confirmDeleteAll = false
        }
    }
}


@Model final class ForgetOnClose {
    var id = UUID()
    var site: String
    var profile: String

    init(_ site: String, profile: String) {
        self.site = site
        self.profile = profile
    }

}

@MainActor
final class ForgetManager: ObservableObject {
    static let shared = ForgetManager()

    @Published private(set) var list: [ForgetOnClose] = []

    func load() {
       let query = FetchDescriptor<ForgetOnClose>()
        do {
            list = try ForgetManager.sharedContainer.mainContext.fetch(query)
            print("Loaded \(list.count) forget-on-close items.")
        } catch {
            print("❌ Failed to load forget-on-close items: \(error)")
        }
    }

    private init() {
        load()
    }

    static let sharedContainer: ModelContainer = {
        let schema = Schema([ForgetOnClose.self])
        do {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Balance", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                "ForgetOnClose",
                schema: schema,
                url: directory.appendingPathComponent("ForgetOnClose.store")
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

    func add(_ url: String, profile: String) {
        let site = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !site.isEmpty else {
            print("⚠️ History: URL was empty, skipping.")
            return
        }

        if list.contains(where: { $0.site.caseInsensitiveCompare(site) == .orderedSame && $0.profile == profile }) {
            print("ℹ️ \(site) is already marked forget-on-close for this profile, skipping insert.")
            return
        }

        do {
            let newItem = ForgetOnClose(site, profile: profile)
            ForgetManager.sharedContainer.mainContext.insert(newItem)
            print("✅ Inserted new history item")

            try ForgetManager.sharedContainer.mainContext.save()
            load()

        } catch {
            print("❌ SwiftData Error: \(error.localizedDescription)")
        }
    }

    func remove(site: String, profile: String) -> Bool {
        do {
            let items = try ForgetManager.sharedContainer.mainContext.fetch(FetchDescriptor<ForgetOnClose>())
            let matches = items.filter {
                $0.profile == profile && $0.site.caseInsensitiveCompare(site) == .orderedSame
            }
            for item in matches {
                ForgetManager.sharedContainer.mainContext.delete(item)
            }
            try ForgetManager.sharedContainer.mainContext.save()
            load()
            return true
        } catch {
            print("❌ Failed to remove forget site: \(error)")
            ForgetManager.sharedContainer.mainContext.rollback()
            return false
        }
    }


    func forget(site: ForgetOnClose) async {
        let domain = site.site.lowercased()
        let profileID = site.profile
        let store: WKWebsiteDataStore
        if let uuid = UUID(uuidString: profileID) {
            store = WKWebsiteDataStore(forIdentifier: uuid)
        } else {
            store = WKWebsiteDataStore.default()
        }

        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        let matching = records.filter { record in
            let recordDomain = record.displayName.lowercased()
            return recordDomain == domain || recordDomain.hasSuffix(".\(domain)")
        }
        if !matching.isEmpty {
            await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: matching)
        }

        _ = HistoryManager.deleteHistory(matchingSite: domain)
        print("🧹 Forgot site on close: \(domain) (profile: \(profileID.isEmpty ? "default" : profileID))")
    }

}


// MARK: - 4. Reusable Row Component
struct WebDataRow: View {
    let item: WKWebsiteDataRecord
    let store: WKWebsiteDataStore?
    let reload: () async -> Void

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var forgetManager = ForgetManager.shared

    @State var isForgotten = false

    @State var showPopover = false

    var profile: String
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    CachedAsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(item.displayName)"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack {
                        Text(item.dataTypes.joined(separator: ", ").replacingOccurrences(of: "WKWebsiteDataType", with: ""))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer()

                Button {
         //           forgetManager.load()
                    showPopover.toggle()
                } label: {
                    Text("Manage")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
        }
        .popover(isPresented: $showPopover) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage data for \(item.displayName)")
                    .font(.headline)

                Toggle(isOn: $isForgotten) {
                    Text("Forget on Close")
                }
                .onChange(of: isForgotten) { _, newValue in
                    if newValue {
                        forgetManager.add(item.displayName, profile:profile)
                    } else {
                        _ = forgetManager.remove(site: item.displayName.lowercased(), profile: profile)
                    }
                }

                ForEach(Array(item.dataTypes).sorted(), id: \.self) { type in
                    HStack {
                        Text(type.replacingOccurrences(of: "WKWebsiteDataType", with: ""))
                            .font(.subheadline)
                        Spacer()
                        Button(role: .destructive) {
                            Task { @MainActor in
                                showPopover = false
                                if let store = store {
                                    await store.removeData(ofTypes: [type], for: [item])
                                    await reload()
                                }
                            }
                        } label: {
                            Text("Delete")
                        }
                    }
                }
                Button(role: .destructive) {
                    Task { @MainActor in
                        showPopover = false
                        if let store = store {
                            await store.removeData(ofTypes: item.dataTypes, for: [item])
                            await reload()
                        }
                    }
                } label: {
                    Text("Delete All for Site")
                        .frame(maxWidth:.infinity)
                }
            }
            .padding()
            .frame(minWidth: 280)
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .task {
            forgetManager.load()
            isForgotten = forgetManager.list.contains(where: {
                $0.site.caseInsensitiveCompare(item.displayName) == .orderedSame && $0.profile == profile
            })
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
