import SwiftUI
import WebKit
internal import UniformTypeIdentifiers

enum ContentBlockerRuleStore {
    nonisolated static let identifierPrefix = "dynamicRules-"

    nonisolated static func identifier(for fileURL: URL) -> String {
        identifierPrefix + fileURL.lastPathComponent
    }

    /// Idempotently removes a compiled rule list. WebKit reports error 8 when
    /// another cleanup has already removed the same identifier, so verify the
    /// store after a failure before surfacing it to the user.
    static func remove(
        identifier: String,
        completion: @escaping (Error?) -> Void = { _ in }
    ) {
        removeDiskRuleList(forIdentifier: identifier)

        guard let store = WKContentRuleListStore.default() else {
            completion(nil)
            return
        }

        store.getAvailableContentRuleListIdentifiers { identifiers in
            guard identifiers?.contains(identifier) == true else {
                completion(nil)
                return
            }

            store.removeContentRuleList(forIdentifier: identifier) { error in
                guard let error else {
                    completion(nil)
                    return
                }

                store.getAvailableContentRuleListIdentifiers { remainingIdentifiers in
                    completion(remainingIdentifiers?.contains(identifier) == true ? error : nil)
                }
            }
        }
    }

    /// Removes compiled lists whose source JSON no longer exists. This also
    /// cleans up artifacts left behind by versions that only deleted the JSON,
    /// as well as unreferenced rule lists (e.g. com.apple.WebPrivacy.ResourceMonitorURLsRuleList).
    static func removeOrphans(for sourceFiles: [URL]) {
        let expectedIdentifiers = Set(sourceFiles.map(identifier(for:)))
        
        cleanDiskRuleLists(keeping: expectedIdentifiers)

        guard let store = WKContentRuleListStore.default() else { return }

        store.getAvailableContentRuleListIdentifiers { identifiers in
            guard let identifiers else { return }
            for identifier in identifiers where !expectedIdentifiers.contains(identifier) {
                remove(identifier: identifier) { error in
                    if let error {
                        print("Failed to remove orphaned content blocker \(identifier): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private static func removeDiskRuleList(forIdentifier identifier: String) {
        guard let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let ruleListsDir = libraryDir.appendingPathComponent("WebKit/ContentRuleLists", isDirectory: true)
        let candidates = [
            ruleListsDir.appendingPathComponent("ContentRuleList-\(identifier)"),
            ruleListsDir.appendingPathComponent(identifier)
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.path) {
                try? FileManager.default.removeItem(at: candidate)
            }
        }
    }

    private static func cleanDiskRuleLists(keeping expectedIdentifiers: Set<String>) {
        guard let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let ruleListsDir = libraryDir.appendingPathComponent("WebKit/ContentRuleLists", isDirectory: true)
        guard FileManager.default.fileExists(atPath: ruleListsDir.path) else { return }

        guard let files = try? FileManager.default.contentsOfDirectory(at: ruleListsDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let filename = file.lastPathComponent
            let isExpected = expectedIdentifiers.contains { expectedId in
                filename == "ContentRuleList-\(expectedId)" ||
                filename.hasPrefix("ContentRuleList-\(expectedId).") ||
                filename == expectedId
            }
            if !isExpected {
                try? FileManager.default.removeItem(at: file)
            }
        }

        if expectedIdentifiers.isEmpty {
            if let remaining = try? FileManager.default.contentsOfDirectory(at: ruleListsDir, includingPropertiesForKeys: nil), remaining.isEmpty {
                try? FileManager.default.removeItem(at: ruleListsDir)
            }
        }
    }
}

struct ContentBlockerView: View {
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345
    
    @State private var errorMessage: String?
    @State private var isInstalling: Bool = false
    @State private var contentBlockers: [URL] = []
    @State private var isChoosingFile = false
    @State private var isEnteringURL = false
    @State private var draftURL = ""
    
    var isSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            if isSettings {
                SettingsCustomCardRow(
                    title: "Add Content Blocker",
                    icon: "plus",
                    accentColor: catContetBlocker.color
                ) {
                    addContentBlockerMenu()
                }
                .padding(.bottom, 8)
                
                SettingsCardRow(
                    setting: Setting(
                        name:"Manage",
                        category: catBookmarks,
                        type:"header",
                        appStorageKey:"",
                    ),
                    icon: "gearshape",
                    accentColor: catContetBlocker.color
                )

            } else {
                HStack {
                    Text("Content Blockers")
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    addContentBlockerMenu()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // MARK: - Content Blockers List
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if contentBlockers.isEmpty && !isInstalling {
                        VStack(spacing: 12) {
                            Image(systemName: "shield")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No Content Blockers")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Use the + menu to add rules from a .json file or URL.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(Array(contentBlockers.enumerated()), id: \.offset) { index, url in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(url.lastPathComponent.replacingOccurrences(of: ".json", with: ""))
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                    }
                                    Spacer()
                                    Button {
                                        deleteContentBlocker(at: url)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.platformControlBackground.opacity(0.4))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, isSettings ? 0 : 16)
                    }
                }
            }
            .padding(.horizontal, isSettings ? 16 : 0)

            
            if isInstalling {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Adding…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
        }
        .padding(.vertical, isSettings ? 0 : 8)
        .frame(maxWidth: isSettings ? .infinity : CGFloat(sidebarWidth))
        .onAppear {
            loadContentBlockers()
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { installFile(at: url) }
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .alert("Add Content Blocker from URL", isPresented: $isEnteringURL) {
            TextField("https://example.com/rules.json", text: $draftURL)
            Button("Cancel", role: .cancel) {}
            Button("Add") { installFromURL(urlStr: draftURL, filename: "") }
        } message: {
            Text("Enter the URL of a .json rule list.")
        }
    }
    
    // MARK: - Actions
    
    private func getDirectory() -> URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        
        let dir = base.appendingPathComponent("ContentBlockers", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func loadContentBlockers() {
        guard let dir = getDirectory() else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            contentBlockers = files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            ContentBlockerRuleStore.removeOrphans(for: contentBlockers)
        } catch {
            print("Failed to load content blockers: \(error)")
        }
    }
    
    private func installFromFile() {
        isChoosingFile = true
    }

    private func installFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            isInstalling = true
            errorMessage = nil
            
            guard let dir = getDirectory() else {
                errorMessage = "Could not find directory"
                isInstalling = false
                return
            }
            
            let destinationURL = dir.appendingPathComponent(url.lastPathComponent)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                loadContentBlockers()
                isInstalling = false
            } catch {
                errorMessage = error.localizedDescription
                isInstalling = false
            }
    }
    
    private func installFromURL(urlStr: String, filename: String) {
        
        var urlString = ""
        
        if(urlStr.isEmpty) {
            draftURL = ""
            isEnteringURL = true
            return
        } else {
            urlString = urlStr
        }
            guard let url = URL(string: urlString), !urlString.isEmpty else {
                errorMessage = "Invalid URL"
                return
            }
        
        
        isInstalling = true
        errorMessage = nil
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse, 
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                guard let dir = getDirectory() else {
                    throw NSError(domain: "ContentBlockerView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find directory"])
                }
                
                let fileName = url.lastPathComponent.isEmpty || url.lastPathComponent == "/" ? "rules-\(UUID().uuidString).json" : url.lastPathComponent
                let finalFileName = fileName.hasSuffix(".json") ? fileName : fileName + ".json"
                
                let destinationURL = dir.appendingPathComponent(filename.isEmpty ? finalFileName : filename)
                
                try data.write(to: destinationURL)
                
                await MainActor.run {
                    loadContentBlockers()
                    isInstalling = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isInstalling = false
                }
            }
        }
    }
    
    private func deleteContentBlocker(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            contentBlockers.removeAll { $0 == url }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        ContentBlockerRuleStore.remove(
            identifier: ContentBlockerRuleStore.identifier(for: url)
        ) { error in
            guard let error else { return }
            DispatchQueue.main.async {
                errorMessage = "The JSON was deleted, but its compiled content blocker could not be removed: \(error.localizedDescription)"
            }
        }

        ContentBlockerRuleStore.removeOrphans(for: contentBlockers)
    }
    
    @ViewBuilder
    private func addContentBlockerMenu() -> some View {
        Menu {
            Button(action: installFromFile) {
                Label("Add from File…", systemImage: "folder")
            }
            Button {
                installFromURL(urlStr: "", filename: "")
            } label: {
                Label("Add from URL…", systemImage: "link")
            }
            Divider()
            Button {
                installFromURL(urlStr: "https://easylist-downloads.adblockplus.org/easylist_content_blocker.json", filename: "Ad Blocker (Easylist).json")
            } label: {
                Label("Ad Blocker (Easylist)", systemImage: "shield.slash")
            }
        } label: {
            if isSettings {
                Text("Add")
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    //    .menuStyle(isSettings ? .borderedButton : .borderlessButton)
        .controlSize(isSettings ? .small : .regular)
        .fixedSize()
        .help("Add Content Blocker")
    }
}
