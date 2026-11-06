#if canImport(UIKit)
import UIKit
public typealias UniversalImage = UIImage
public typealias PlatformViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
import AppKit
public typealias UniversalImage = NSImage
public typealias PlatformViewRepresentable = NSViewRepresentable
#endif

import SwiftUI
internal import Combine

extension Image {
    init(universalImage: UniversalImage) {
        #if canImport(UIKit)
        self.init(uiImage: universalImage)
        #elseif canImport(AppKit)
        self.init(nsImage: universalImage)
#endif

    }
}

@MainActor
final class SwiftUIPresentationCenter: ObservableObject {
    static let shared = SwiftUIPresentationCenter()
    struct Request: Identifiable {
        enum Kind: Equatable { case message, confirmation, permission, text }
        let id = UUID()
        let windowID: String
        let kind: Kind
        let title: String
        let message: String
        let items: [String]
        let placeholder: String?
        let initialText: String
        let primaryTitle: String
        let completion: (String?) -> Void
    }
    @Published var request: Request?
    private var pending: [Request] = []
    private var isDismissing = false

    func message(_ title: String, message: String = "") {
        present(.message, title: title, message: message, primaryTitle: "OK") { _ in }
    }

    func confirm(_ title: String, message: String = "", primaryTitle: String = "Allow", completion: @escaping (Bool) -> Void) {
        present(.confirmation, title: title, message: message, primaryTitle: primaryTitle) { completion($0 != nil) }
    }

    func permission(_ title: String, message: String = "", items: [String] = [], tabID: String? = nil, completion: @escaping (Bool) -> Void) {
        present(.permission, title: title, message: message, items: items, tabID: tabID, primaryTitle: "Allow") { completion($0 != nil) }
    }

    func prompt(_ title: String, message: String = "", placeholder: String, initialText: String = "", primaryTitle: String = "OK", completion: @escaping (String?) -> Void) {
        present(.text, title: title, message: message, placeholder: placeholder, initialText: initialText, primaryTitle: primaryTitle, completion: completion)
    }

    private func present(_ kind: Request.Kind, title: String, message: String, items: [String] = [], tabID: String? = nil, placeholder: String? = nil, initialText: String = "", primaryTitle: String, completion: @escaping (String?) -> Void) {
        let manager = WindowManager.shared
        let windowID = tabID.flatMap { tabID in
            manager.browserWindows.first { $0.tabs.contains { $0.id == tabID } }?.id
        } ?? manager.activeWindowID ?? manager.browserWindows.first?.id
        guard let windowID else { completion(nil); return }
        let newRequest = Request(windowID: windowID, kind: kind, title: title, message: message, items: items, placeholder: placeholder, initialText: initialText, primaryTitle: primaryTitle, completion: completion)
        if request == nil && !isDismissing {
            request = newRequest
        } else {
            pending.append(newRequest)
        }
    }

    func finish(_ shownRequest: Request, value: String?) {
        guard request?.id == shownRequest.id else { return }
        isDismissing = true
        request = nil
        shownRequest.completion(value)
    }

    func showNext() {
        isDismissing = false
        guard request == nil, !pending.isEmpty else { return }
        request = pending.removeFirst()
    }

    func cancelRequests(for windowID: String) {
        if let request, request.windowID == windowID { finish(request, value: nil) }
        let cancelled = pending.filter { $0.windowID == windowID }
        pending.removeAll { $0.windowID == windowID }
        cancelled.forEach { $0.completion(nil) }
        showNext()
    }
}

private struct SwiftUIPresentationHost: ViewModifier {
    @ObservedObject private var center = SwiftUIPresentationCenter.shared
    @State private var text = ""
    let windowID: String

    private var presentedRequest: Binding<SwiftUIPresentationCenter.Request?> {
        Binding(
            get: { center.request?.windowID == windowID ? center.request : nil },
            set: { if $0 == nil, let request = center.request, request.windowID == windowID { center.finish(request, value: nil) } }
        )
    }

    func body(content: Content) -> some View {
        content.sheet(item: presentedRequest, onDismiss: { center.showNext() }) { request in
            VStack(spacing: 0) {
                if request.kind == .permission {
                    Form {
                        Section {
                            Label(request.title, systemImage: "lock.shield")
                                .font(.title3.weight(.semibold))
                            if !request.message.isEmpty {
                                Text(request.message).foregroundStyle(.secondary)
                            }
                        }
                        if !request.items.isEmpty {
                            Section("Requested Access") {
                                ForEach(request.items, id: \.self) { item in
                                    Text(item)
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(request.title).font(.title3.bold())
                        if !request.message.isEmpty { Text(request.message).foregroundStyle(.secondary) }
                        if let placeholder = request.placeholder {
                            TextField(placeholder, text: $text)
                                .textFieldStyle(.roundedBorder)
                                .onAppear { text = request.initialText }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                HStack {
                    Spacer()
                    if request.kind != .message {
                        Button(request.kind == .permission ? "Deny" : "Cancel", role: .cancel) {
                            center.finish(request, value: nil)
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                    }
                    Button(request.primaryTitle) {
                        center.finish(request, value: request.kind == .text ? text : "confirmed")
                    }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .padding()
            }
            .frame(minWidth: 280, idealWidth: 420, maxWidth: 520, minHeight: request.kind == .permission ? 250 : 180)
                .interactiveDismissDisabled()
#if os(iOS)
                .presentationDetents([.medium]).presentationDragIndicator(.visible)
#endif
        }
        .onDisappear { center.cancelRequests(for: windowID) }
    }
}

extension View {
    func swiftUIPresentationHost(windowID: String) -> some View { modifier(SwiftUIPresentationHost(windowID: windowID)) }

    @ViewBuilder func fittedMenuPopover(
        width: CGFloat = 340,
        minHeight: CGFloat = 360,
        idealHeight: CGFloat = 500,
        maxHeight: CGFloat = 600
    ) -> some View {
        self.frame(
            minWidth: width,
            idealWidth: width,
            maxWidth: width,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight
        )
#if os(iOS)
        .fixedSize(horizontal: true, vertical: false)
        .presentationSizing(.fitted)
        .presentationCompactAdaptation(.popover)
#endif
    }

    @ViewBuilder func roomyToolbarPopover(minHeight: CGFloat = 360) -> some View {
#if os(iOS)
        self.frame(
            minWidth: 340,
            idealWidth: 420,
            maxWidth: 560,
            minHeight: minHeight,
            idealHeight: max(minHeight, 560)
        )
        .presentationCompactAdaptation(.sheet)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
#else
        self.frame(minWidth: 280, idealWidth: 380, maxWidth: 520, minHeight: minHeight, idealHeight: 500)
#endif
    }
}

extension UniversalImage {
    static func load(contentsOf url: URL) -> UniversalImage? {
        #if canImport(UIKit)
        UIImage(contentsOfFile: url.path)
        #elseif canImport(AppKit)
        NSImage(contentsOf: url)
        #endif
    }

    var pngData: Data? {
        #if canImport(UIKit)
        pngData()
        #else
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }
}

extension Color {
    static var platformWindowBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var platformControlBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var platformTextBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .textBackgroundColor)
        #endif
    }

    static var platformSeparator: Color {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    static var platformAccent: Color {
        #if canImport(UIKit)
        Color(uiColor: .tintColor)
        #else
        Color(nsColor: .controlAccentColor)
        #endif
    }
}

enum PlatformApplication {
    static func open(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    static func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #elseif canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }
}
