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
        let id = UUID(); let title: String; let message: String
        let placeholder: String?; let initialText: String; let primaryTitle: String
        let completion: (String?) -> Void
    }
    @Published var request: Request?
    func message(_ title: String, message: String = "") { present(title, message: message, primaryTitle: "OK") { _ in } }
    func confirm(_ title: String, message: String = "", primaryTitle: String = "Allow", completion: @escaping (Bool) -> Void) { present(title, message: message, primaryTitle: primaryTitle) { completion($0 != nil) } }
    func prompt(_ title: String, message: String = "", placeholder: String, initialText: String = "", primaryTitle: String = "OK", completion: @escaping (String?) -> Void) { present(title, message: message, placeholder: placeholder, initialText: initialText, primaryTitle: primaryTitle, completion: completion) }
    private func present(_ title: String, message: String, placeholder: String? = nil, initialText: String = "", primaryTitle: String, completion: @escaping (String?) -> Void) { request = Request(title: title, message: message, placeholder: placeholder, initialText: initialText, primaryTitle: primaryTitle, completion: completion) }
}

private struct SwiftUIPresentationHost: ViewModifier {
    @ObservedObject private var center = SwiftUIPresentationCenter.shared
    @State private var text = ""
    func body(content: Content) -> some View {
        content.sheet(item: $center.request) { request in
            VStack(alignment: .leading, spacing: 18) {
                Text(request.title).font(.title3.bold())
                if !request.message.isEmpty { Text(request.message).foregroundStyle(.secondary) }
                if let placeholder = request.placeholder { TextField(placeholder, text: $text).textFieldStyle(.roundedBorder).onAppear { text = request.initialText } }
                HStack {
                    Button("Cancel", role: .cancel) { center.request = nil; request.completion(nil) }
                    Spacer()
                    Button(request.primaryTitle) { let value = request.placeholder == nil ? "confirmed" : text; center.request = nil; request.completion(value) }.buttonStyle(.borderedProminent)
                }
            }.padding(24).frame(minWidth: 280, idealWidth: 420, maxWidth: 520, minHeight: 220)
#if os(iOS)
                .presentationDetents([.medium]).presentationDragIndicator(.visible)
#endif
        }
    }
}

extension View {
    func swiftUIPresentationHost() -> some View { modifier(SwiftUIPresentationHost()) }

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
