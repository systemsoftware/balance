import SwiftUI
import WebKit
internal import UniformTypeIdentifiers

struct ExtensionsView: View {
    @ObservedObject private var manager = WebExtensionManager.shared
    
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345
    
    @State private var errorMessage: String?
    @State private var isInstalling: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text("Extensions")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                
                Menu {
                    Button(action: installFromFile) {
                        Label("Install from File…", systemImage: "folder")
                    }
                    Button(action: installFromURL) {
                        Label("Install from URL…", systemImage: "link")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Install extension")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // MARK: - Extension List
            ScrollView {
                if manager.contexts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No Extensions Installed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Use the + menu to install extensions from a .crx file or URL.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.contexts, id: \.baseURL) { context in
                            ExtensionRow(context: context, onUninstall: {
                                manager.removeExtensionFromDisk(context)
                            }, onOpenOptions: {
                                openOptionsPage(for: context)
                            }, onUpdate: {
                                updateExtension(context)
                            })
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            
            if isInstalling {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Installing…")
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
        .padding(.vertical)
        .frame(width: CGFloat(sidebarWidth))
    }
    
    // MARK: - Actions
    
    private func installFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a .crx Extension"
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            isInstalling = true
            errorMessage = nil
            Task {
                do {
                    try await CRXInstaller.install(from: url)
                    await MainActor.run { isInstalling = false }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isInstalling = false
                    }
                }
            }
        }
    }
    
    private func installFromURL() {
        let alert = NSAlert()
        alert.messageText = "Install Extension from URL"
        alert.informativeText = "Enter the URL of a .crx extension file:"
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "https://example.com/extension.crx"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let urlString = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            errorMessage = "Invalid URL"
            return
        }
        
        isInstalling = true
        errorMessage = nil
        
        Task {
            do {
                let crxFile = try await CRXInstaller.download(from: url)
                try await CRXInstaller.install(from: crxFile, originalURL: url)
                await MainActor.run {
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
    
    private func openOptionsPage(for context: WKWebExtensionContext) {
        if let optionsURL = context.optionsPageURL {
            createNewTab(with: optionsURL)
        }
    }
    
    private func updateExtension(_ context: WKWebExtensionContext) {
        let manifest = context.webExtension.manifest
        let extID = context.baseURL.lastPathComponent
        
        if let updateURL = manifest["update_url"] as? String,
           let url = URL(string: updateURL) {
            performUpdate(removing: context, from: url)
        } else if extID.count == 32 {
            let cwsURL = "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=114.0.0.0&acceptformat=crx2,crx3&x=id%3D" + extID + "%26installsource%3Dondemand%26uc"
            if let url = URL(string: cwsURL) {
                performUpdate(removing: context, from: url)
            }
        } else {
            errorMessage = "No update URL available for this extension."
        }
    }
    
    private func performUpdate(removing context: WKWebExtensionContext, from url: URL) {
        isInstalling = true
        errorMessage = nil
        manager.removeExtensionFromDisk(context)
        Task {
            do {
                let crx = try await CRXInstaller.download(from: url)
                try await CRXInstaller.install(from: crx, originalURL: url)
                await MainActor.run { isInstalling = false }
            } catch {
                await MainActor.run {
                    errorMessage = "Update failed: \(error.localizedDescription)"
                    isInstalling = false
                }
            }
        }
    }
}

// MARK: - Extension Row

struct ExtensionRow: View {
    let context: WKWebExtensionContext
    let onUninstall: () -> Void
    let onOpenOptions: () -> Void
    let onUpdate: () -> Void
    
    private var displayName: String {
        context.webExtension.manifest["name"] as? String ?? "Unknown Extension"
    }
    
    private var version: String {
        context.webExtension.manifest["version"] as? String ?? "—"
    }
    
    private var extensionDescription: String {
        context.webExtension.manifest["description"] as? String ?? "No description"
    }
    
    private var hasOptionsPage: Bool {
        context.optionsPageURL != nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                if let icon = context.webExtension.icon(for: CGSize(width:20,height: 20)) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(displayName)
                        .font(.system(.subheadline, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(extensionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if hasOptionsPage {
                    onOpenOptions()
                }
            }
            
            // Actions
            HStack(spacing: 4) {
                Button(action: onUpdate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Update extension")
                
                Button(action: onUninstall) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Uninstall extension")
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Notification for opening URLs

extension Notification.Name {
    static let optionsTapped = Notification.Name("optionsTapped")
}
