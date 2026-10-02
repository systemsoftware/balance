import SwiftUI
import Foundation
import SwiftData
#if os(macOS)
import AppKit
#endif

@Model
final class UserScript {
    var id: UUID
    var name: String
    var domain: String
    var executionType: String
    var isEnabled: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, domain: String, executionType: ScriptExecType) {
        self.id = id
        self.name = name
        self.domain = domain
        self.executionType = executionType.rawValue
        self.isEnabled = true
        self.createdAt = Date()
    }
}

@MainActor
enum UserScriptStore {
    static let didChange = Notification.Name("BalanceUserScriptsDidChange")
    private static var cachedScripts: [(script: UserScript, source: String)]?
    private static var cachedFileVersions: [UUID: (modified: Date, size: Int)] = [:]
    private(set) static var revision: UInt = 0

    private static func invalidateCache() {
        cachedScripts = nil
        cachedFileVersions.removeAll()
        revision &+= 1
    }

    static let container: Result<ModelContainer, Error> = Result {
        let schema = Schema([UserScript.self])
        let directory = try scriptsDirectory.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(
            "Scripts",
            schema: schema,
            url: directory.appendingPathComponent("Scripts.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static var scriptsDirectory: URL {
        get throws {
            guard let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            return applicationSupport
                .appendingPathComponent("Balance", isDirectory: true)
                .appendingPathComponent("Scripts", isDirectory: true)
        }
    }

    static func fileURL(for id: UUID) throws -> URL {
        try scriptsDirectory.appendingPathComponent("\(id.uuidString).js")
    }

    static func create(name: String, domain: String, executionType: ScriptExecType, source: String) throws {
        let script = UserScript(name: name, domain: domain, executionType: executionType)
        let context = try container.get().mainContext
        let directory = try scriptsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = try fileURL(for: script.id)
        try Data(source.utf8).write(to: url, options: .atomic)

        context.insert(script)
        do {
            try context.save()
            invalidateCache()
            NotificationCenter.default.post(name: didChange, object: nil)
        } catch {
            context.rollback()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    static func allScripts() throws -> [UserScript] {
        let context = try container.get().mainContext
        return try context.fetch(FetchDescriptor<UserScript>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
    }

    static func delete(_ script: UserScript) throws {
        let context = try container.get().mainContext
        context.delete(script)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        if let url = try? fileURL(for: script.id) {
            try? FileManager.default.removeItem(at: url)
        }
        invalidateCache()
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func setEnabled(_ enabled: Bool, for script: UserScript) throws {
        let context = try container.get().mainContext
        script.isEnabled = enabled
        do {
            try context.save()
            invalidateCache()
            NotificationCenter.default.post(name: didChange, object: nil)
        } catch {
            context.rollback()
            throw error
        }
    }

    static func enabledScripts() throws -> [(script: UserScript, source: String)] {
        if let cachedScripts {
            let filesAreCurrent = cachedScripts.allSatisfy { entry in
                guard let url = try? fileURL(for: entry.script.id),
                      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let modified = attributes[.modificationDate] as? Date,
                      let size = attributes[.size] as? Int,
                      let version = cachedFileVersions[entry.script.id] else { return false }
                return modified == version.modified && size == version.size
            }
            if filesAreCurrent { return cachedScripts }
        }

        let context = try container.get().mainContext
        let descriptor = FetchDescriptor<UserScript>(sortBy: [SortDescriptor(\.createdAt)])
        var versions: [UUID: (modified: Date, size: Int)] = [:]
        let scripts = try context.fetch(descriptor).compactMap { script -> (script: UserScript, source: String)? in
            guard script.isEnabled,
                  ScriptExecType(rawValue: script.executionType) != nil,
                  let url = try? fileURL(for: script.id),
                  let source = try? String(contentsOf: url, encoding: .utf8) else {
                return nil
            }
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let modified = attributes[.modificationDate] as? Date,
               let size = attributes[.size] as? Int {
                versions[script.id] = (modified, size)
            }
            return (script, source)
        }
        cachedScripts = scripts
        cachedFileVersions = versions
        revision &+= 1
        return scripts
    }
}

enum ScriptExecType: String, CaseIterable, Identifiable {
    case documentStart = "docStart"
    case documentEnd = "docEnd"
    case documentIdle = "docIdle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documentStart:
            return "Document Start"
        case .documentEnd:
            return "Document End"
        case .documentIdle:
            return "Document Idle"
        }
    }
}

struct NewScriptView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var domain = ""
    @State private var type: ScriptExecType = .documentEnd
    @State private var source = "console.log('Hello, world!');"
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Userscript")
                .font(.system(.headline, design: .rounded))

            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Domain", text: $domain)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Execution Time")
                    Spacer()
                    Picker("", selection: $type) {
                        ForEach(ScriptExecType.allCases) { execType in
                            Text(execType.title).tag(execType)
                        }
                    }
                }

                Text("Script")
                TextEditor(text: $source)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Create Script") { saveScript() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .alert("Couldn't Save Userscript", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func saveScript() {
        do {
            try UserScriptStore.create(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                domain: domain.trimmingCharacters(in: .whitespacesAndNewlines),
                executionType: type,
                source: source
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}



struct ScriptsView: View {
    @State private var scripts: [UserScript] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SettingsCardRow(
                setting: Setting(
                    name:"Manage",
                    category: catBookmarks,
                    type:"header",
                    appStorageKey:"",
                ),
                icon: "gearshape",
                accentColor: catExt.color
            )
            .padding(.top, -18)

            ScrollView {
                if scripts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No Userscripts")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Create a userscript to get started.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(scripts, id: \.id) { script in
                            ScriptRow(script: script, onOpen: {
                                do {
                                    let url = try UserScriptStore.fileURL(for: script.id)
                                    guard FileManager.default.fileExists(atPath: url.path) else {
                                        throw CocoaError(.fileNoSuchFile)
                                    }
                                    #if os(macOS)
                                    if !NSWorkspace.shared.open(url) {
                                        errorMessage = "Couldn't open \(script.name)."
                                    }
                                    #else
                                    PlatformApplication.open(url)
                                    #endif
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }, onToggle: { enabled in
                                do {
                                    try UserScriptStore.setEnabled(enabled, for: script)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }, onUninstall: {
                                do {
                                    try UserScriptStore.delete(script)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            })
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .frame(maxWidth: .infinity)
            .onAppear(perform: reloadScripts)
            .onReceive(NotificationCenter.default.publisher(for: UserScriptStore.didChange)) { _ in
                reloadScripts()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    private func reloadScripts() {
        do {
            scripts = try UserScriptStore.allScripts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


    struct ScriptRow: View {
        let script: UserScript
        let onOpen: () -> Void
        let onToggle: (Bool) -> Void
        let onUninstall: () -> Void

        var body: some View {
            HStack(alignment: .center, spacing: 10) {
                Button(action: onOpen) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Favicon(script.domain)
                        }
                        Text(script.name)
                            .font(.system(.subheadline, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("Enabled", isOn: Binding(
                    get: { script.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help(script.isEnabled ? "Disable userscript" : "Enable userscript")
                .padding(.trailing, 4)

                Button(action: onUninstall) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete userscript")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.platformWindowBackground.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }
