import SwiftUI
import WebKit
internal import UniformTypeIdentifiers

struct ContentBlockerView: View {
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345
    
    @State private var errorMessage: String?
    @State private var isInstalling: Bool = false
    @State private var contentBlockers: [URL] = []
    
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
                                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
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
        } catch {
            print("Failed to load content blockers: \(error)")
        }
    }
    
    private func installFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a .json Content Blocker Rule List"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
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
    }
    
    private func installFromURL(urlStr: String, filename: String) {
        
        var urlString = ""
        
        if(urlStr.isEmpty) {
            let alert = NSAlert()
            alert.messageText = "Add Content Blocker from URL"
            alert.informativeText = "Enter the URL of a .json rule list:"
            alert.addButton(withTitle: "Add")
            alert.addButton(withTitle: "Cancel")
            
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.placeholderString = "https://example.com/rules.json"
            alert.accessoryView = input
            alert.window.initialFirstResponder = input
            
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            
            urlString = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
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
            loadContentBlockers()
        } catch {
            errorMessage = error.localizedDescription
        }
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
