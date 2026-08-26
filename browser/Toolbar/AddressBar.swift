import SwiftUI
import WebKit

struct AddressBar: View {
    @ObservedObject var browserState: BrowserState
    @Binding var location: URL?
    @Binding var urlInput: String
    @Binding var showTrustInfo: Bool
    @Binding var showTabSearch: Bool
    @Binding var showEventPopup: Bool
    @Binding var showGoTo: Bool

    let focusOnAppear: Bool
    let isPrivate: Bool
    let profileIcon: String?
    let profileName: String?
    let events: [EventExtraction]
    let submitURL: () -> Void

    var body: some View {
        HStack {
                if location?.absoluteString.starts(with: "http") == true {
                    TrustIndicator(trust: browserState.serverTrust, url: location, isPresented: $showTrustInfo)
                        .popover(isPresented: $showTrustInfo) {
                            ServerTrustView(
                                trust: browserState.serverTrust,
                                url: browserState.url,
                                dataStore: browserState.webView?.configuration.websiteDataStore,
                                onAttemptHTTPS: attemptHTTPS
                            )
                        }
                        .padding(.leading)
                }

                AddressField(text: $urlInput, focusOnAppear: focusOnAppear, onSubmit: submitURL)
                Spacer()

                if isPrivate {
                    Image(systemName: "eye.slash.fill")
                        .help("Private Mode")
                        .padding(.trailing, 10)
                }

                if let profileIcon, let profileName, !profileName.isEmpty {
                    Image(systemName: profileIcon)
                        .help("Profile: \(profileName)")
                        .padding(.trailing, 10)
                }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        .sheet(isPresented: $showTabSearch) {
                TabSearchView(isPopover: true)
                Button("Close") { showTabSearch = false }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
        }
        .sheet(isPresented: $showEventPopup) {
                EventListSheet(events: events)
        }
        .sheet(isPresented: $showGoTo) {
                VStack {
                    TextField("Enter URL", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                    HStack {
                        Button("Cancel") { showGoTo = false }
                        Button("Go") {
                            showGoTo = false
                            submitURL()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding()
        }
    }

    private func attemptHTTPS() {
        guard let location,
              var components = URLComponents(url: location, resolvingAgainstBaseURL: false) else {
            return
        }
        components.scheme = "https"
        self.location = components.url
    }
}

private struct TrustIndicator: View {
    let trust: SecTrust?
    let url: URL?
    @Binding var isPresented: Bool

    var body: some View {
        Group {
            if let trust {
                Button(action: { isPresented.toggle() }) {
                    var error: CFError?
                    if SecTrustEvaluateWithError(trust, &error) {
                        Image(systemName: "lock.fill")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
            } else if url?.scheme == "http" {
                Button(action: { isPresented.toggle() }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AddressField: View {
    @Binding var text: String
    var focusOnAppear = false
    let onSubmit: () -> Void

    var body: some View {
        NativeAddressField(text: $text, onSubmit: onSubmit, focusOnAppear: focusOnAppear)
            .padding(10)
    }
}

private final class IsolatedTextField: NSTextField {
    override var nextKeyView: NSView? {
        get { nil }
        set { }
    }
    override var previousKeyView: NSView? { nil }
    override var nextValidKeyView: NSView? { nil }
    override var previousValidKeyView: NSView? { nil }
}

private struct NativeAddressField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    var focusOnAppear = false

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> IsolatedTextField {
        let field = IsolatedTextField()
        field.delegate = context.coordinator
        field.placeholderString = "Search or enter website name"
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingTail
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: IsolatedTextField, context: Context) {
        context.coordinator.parent = self
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
        if focusOnAppear && !context.coordinator.didFocus {
            context.coordinator.didFocus = true
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeAddressField
        var didFocus = false

        init(parent: NativeAddressField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.onSubmit()
            return true
        }
    }
}
