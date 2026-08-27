import AppKit
import SwiftUI
import WebKit
import SwiftData

internal import UniformTypeIdentifiers

func getMimeType(from url: URL) -> String {
    let extensionString = url.pathExtension
    if let utType = UTType(filenameExtension: extensionString) {
        return utType.preferredMIMEType ?? "application/octet-stream"
    }
    return "application/octet-stream"
}

@Model
final class InventoryItem: Identifiable, Hashable {

    var id: UUID
    var name: String = ""
    var mime: String = "application/octet-stream"
    var url = URL(fileURLWithPath: "")
    var isRemoteLink: Bool = false

    init(id: UUID = UUID(), name: String, url: URL, mime: String, isRemoteLink: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.mime = mime
        self.isRemoteLink = isRemoteLink
    }

}

struct InventorySidebar: View {

    static let sharedContainer: ModelContainer = {
        let schema = Schema([InventoryItem.self])
        do {
            guard let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                fatalError("Unable to locate Application Support")
            }
            let directory = appSupport.appendingPathComponent("Inventory", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let storeURL = directory.appendingPathComponent("Inventory.store")
            let configuration = ModelConfiguration("Inventory", schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to open inventory store: \(error)")
        }
    }()

    @State private var items: [InventoryItem] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .foregroundStyle(.secondary)
                Text("Inventory")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                if !items.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(items, id: \.id) { item in
                            itemRow(item)
                        }
                    }
                    .padding()

                } else {
                    ContentUnavailableView {
                        Label("Drop something here to get started", systemImage: "tray.and.arrow.down")
                    }
                    .padding()

                }
            }
        }
        .onDrop(
            of: [
                UTType.url,
                UTType.fileURL,
                UTType.pdf,
                UTType.html,
                UTType.plainText,
                UTType.text,
                UTType.image,
                UTType.data
            ],
            isTargeted: nil
        ) { providers in
            handleDrop(providers)
            return true
        }
        .task {
            do {
                self.items = try InventorySidebar.sharedContainer.mainContext.fetch(FetchDescriptor<InventoryItem>())
            } catch {
                print(error)
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: InventoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: { open(item) }) {
                    HStack(spacing: 8) {
                        Image(systemName: iconName(for: item))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(item.name)
                            .font(.system(.body, design: .rounded))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                if isCopyable(item) {
                    Button(action: { copy(item) }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(item.isRemoteLink ? "Copy link" : "Copy image")
                }

                Button(action: { delete(item) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }

            if !item.isRemoteLink, item.mime.lowercased().contains("image") {
                if let imgData = try? Data(contentsOf: item.url), let img = NSImage(data: imgData) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("Unable to load image")
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .onDrag {
            dragProvider(for: item)
        }
    }

    private func dragProvider(for item: InventoryItem) -> NSItemProvider {
        if item.isRemoteLink {
            return NSItemProvider(object: item.url as NSURL)
        }
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL)
        if item.mime.lowercased().contains("image"),
           let data = try? Data(contentsOf: item.url),
           let image = NSImage(data: data) {
            provider.registerObject(image, visibility: .all)
        }
        return provider
    }

    private func open(_ item: InventoryItem) {
        if item.isRemoteLink {
            if item.url.scheme == "http" || item.url.scheme == "https" {
                createNewTab(with: item.url)
            } else {
                NSWorkspace.shared.open(item.url)
            }
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    private func isCopyable(_ item: InventoryItem) -> Bool {
        item.isRemoteLink || item.mime.lowercased().contains("image")
    }

    private func copy(_ item: InventoryItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.isRemoteLink {
            pasteboard.setString(item.url.absoluteString, forType: .string)
            return
        }

        guard item.mime.lowercased().contains("image") else { return }

        if let imgData = try? Data(contentsOf: item.url), let img = NSImage(data: imgData) {
            pasteboard.writeObjects([img])
        }
    }

    private func iconName(for item: InventoryItem) -> String {
        if item.isRemoteLink {
            return "link"
        } else if item.mime.lowercased().contains("image") {
            return "photo"
        } else {
            return "doc"
        }
    }

    private func delete(_ item: InventoryItem) {
        let context = InventorySidebar.sharedContainer.mainContext
        do {
            context.delete(item)
            try context.save()
            items.removeAll { $0.id == item.id }
            if !item.isRemoteLink {
                try? FileManager.default.removeItem(at: item.url)
            }
        } catch {
            print("Error deleting item: \(error)")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                    guard error == nil, let data, let url = url(from: data) else { return }
                    Task { await saveURL(url) }
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.url.identifier) { data, error in
                    guard error == nil, let data, let url = url(from: data) else { return }
                    Task { await saveURL(url) }
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, error in
                    guard error == nil, let data else { return }
                    let name = provider.suggestedName ?? "Document.pdf"
                    Task { @MainActor in saveData(data, name: name, type: .pdf) }
                }
                continue
            }

            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { object, error in
                    guard
                        error == nil,
                        let image = object as? NSImage
                    else { return }

                    Task { @MainActor in
                        saveImage(image)
                    }
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.html.identifier) { data, error in
                    guard error == nil, let data, let url = url(fromHTML: data) else { return }
                    Task { await saveURL(url) }
                }
                continue
            }

            let textType = [UTType.plainText, UTType.text].first {
                provider.hasItemConformingToTypeIdentifier($0.identifier)
            }
            if let textType {
                provider.loadDataRepresentation(forTypeIdentifier: textType.identifier) { data, error in
                    guard error == nil, let data else { return }
                    if let url = url(from: data) {
                        Task { await saveURL(url) }
                    } else if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in saveData(Data(text.utf8), name: provider.suggestedName ?? "Text.txt", type: .plainText) }
                    }
                }
                continue
            }

            if let identifier = provider.registeredTypeIdentifiers.first(where: {
                UTType($0)?.conforms(to: .data) == true
            }) {
                provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, error in
                    guard error == nil, let data else { return }
                    let type = UTType(identifier) ?? .data
                    let name = provider.suggestedName ?? "Drop.\(type.preferredFilenameExtension ?? "data")"
                    Task { @MainActor in saveData(data, name: name, type: type) }
                }
            }
        }
    }

    private func url(from data: Data) -> URL? {
        if let url = URL(dataRepresentation: data, relativeTo: nil),
           url.isFileURL || url.scheme != nil {
            return url
        }
        guard let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if let url = URL(string: value), url.isFileURL || url.scheme != nil {
            return url
        }
        let pattern = #"[A-Za-z][A-Za-z0-9+.-]*://[^\s<>\"']+"#
        guard let range = value.range(of: pattern, options: .regularExpression),
              let url = URL(string: String(value[range])) else { return nil }
        return url
    }

    private func url(fromHTML data: Data) -> URL? {
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        let pattern = #"(?:href|src)\s*=\s*[\"']([^\"']+)[\"']"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return URL(string: String(html[range]))
    }

    private var inventoryDirectory: URL {
        let fileManager = FileManager.default

        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let directory = appSupport
            .appendingPathComponent("Inventory", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        return directory
    }

    @MainActor
    private func saveLocalFile(_ sourceURL: URL) {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            var destination = inventoryDirectory
                .appendingPathComponent(sourceURL.lastPathComponent)

            if FileManager.default.fileExists(atPath: destination.path) {
                let name = sourceURL.deletingPathExtension().lastPathComponent
                let ext = sourceURL.pathExtension

                destination = inventoryDirectory
                    .appendingPathComponent("\(name)-\(UUID().uuidString)")
                if !ext.isEmpty {
                    destination.appendPathExtension(ext)
                }
            }

            try FileManager.default.copyItem(
                at: sourceURL,
                to: destination
            )

            addInventoryItem(destination)

        } catch {
            print("Couldn't save dropped file:", error)
        }
    }

    private func saveURL(_ url: URL) async {
        if url.isFileURL {
            await MainActor.run {
                saveLocalFile(url)
            }
            return
        }

        await MainActor.run {
            addLinkItem(url)
        }
    }

    @MainActor
    private func saveData(_ data: Data, name: String, type: UTType) {
        let cleanName = URL(fileURLWithPath: name).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var destination = inventoryDirectory.appendingPathComponent(cleanName.isEmpty ? "Drop" : cleanName)
        if destination.pathExtension.isEmpty, let ext = type.preferredFilenameExtension {
            destination.appendPathExtension(ext)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            let ext = destination.pathExtension
            destination = inventoryDirectory
                .appendingPathComponent(destination.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString)
            if !ext.isEmpty {
                destination.appendPathExtension(ext)
            }
        }
        do {
            try data.write(to: destination)
            addInventoryItem(destination)
        } catch {
            print("Couldn't save dropped data:", error)
        }
    }

    @MainActor
    private func saveImage(_ image: NSImage) {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(
                using: .png,
                properties: [:]
            )
        else {
            return
        }

        let url = inventoryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        do {
            try data.write(to: url)
            addInventoryItem(url)
        } catch {
            print("Couldn't save dropped image:", error)
        }
    }

    @MainActor
    private func addInventoryItem(_ url: URL) {
        let context = InventorySidebar.sharedContainer.mainContext
        let item = InventoryItem(
            name: url.lastPathComponent,
            url: url,
            mime: getMimeType(from: url),
            isRemoteLink: false
        )
        do {
            context.insert(item)
            try context.save()
            items.insert(item, at: 0)
        } catch {
            context.rollback()
            try? FileManager.default.removeItem(at: url)
            print("Couldn't add inventory item:", error)
        }
    }

    @MainActor
    private func addLinkItem(_ url: URL) {
        guard url.isFileURL || url.scheme != nil else { return }
        let context = InventorySidebar.sharedContainer.mainContext
        do {
            let displayName: String = {
                let lastComponent = url.lastPathComponent
                if !lastComponent.isEmpty, lastComponent != "/" {
                    return lastComponent
                }
                return url.host() ?? url.absoluteString
            }()

            let item = InventoryItem(
                name: displayName,
                url: url,
                mime: getMimeType(from: url),
                isRemoteLink: true
            )

            context.insert(item)
            try context.save()
            items.insert(item, at: 0)

        } catch {
            context.rollback()
            print("Couldn't add link item:", error)
        }
    }
}
