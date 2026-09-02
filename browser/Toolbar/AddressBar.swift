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
                // Keep this view in the hierarchy even while WebKit is updating
                // serverTrust. Removing a sibling of the native text field while
                // AppKit is establishing its field editor can corrupt the key-view
                // loop and crash when the address field is clicked.
                TrustIndicator(trust: browserState.serverTrust, url: location, isPresented: $showTrustInfo)
                    .popover(isPresented: $showTrustInfo) {
                        ServerTrustView(
                            trust: browserState.serverTrust,
                            url: location,
                            webView: browserState.webView,
                            dataStore: browserState.webView?.configuration.websiteDataStore,
                            onAttemptHTTPS: attemptHTTPS
                        )
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

    private var isWebURL: Bool {
        url?.scheme == "http" || url?.scheme == "https"
    }

    private var isSecure: Bool {
        guard url?.scheme == "https" else { return false }

        // WebKit publishes the URL before it publishes serverTrust. A committed
        // HTTPS URL is a safe interim state; replace it with the evaluated result
        // as soon as the trust object arrives.
        guard let trust else { return true }
        return SecTrustEvaluateWithError(trust, nil)
    }

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            Image(systemName: isSecure ? "lock.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isSecure ? .primary : .red)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .help(isSecure ? "Connection is secure" : "Connection is not secure")
        .frame(width: isWebURL ? 16 : 0)
        .padding(.leading, isWebURL ? 16 : 0)
        .clipped()
        .opacity(isWebURL ? 1 : 0)
        .allowsHitTesting(isWebURL)
        .accessibilityHidden(!isWebURL)
        .onChange(of: isWebURL) { _, isWebURL in
            if !isWebURL {
                isPresented = false
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
    // Exclude this field from automatic traversal, but leave AppKit's key-view
    // links intact so it can safely unlink the field during tab teardown.
    override var canBecomeKeyView: Bool { false }
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

    static func dismantleNSView(_ field: IsolatedTextField, coordinator: Coordinator) {
        if let window = field.window,
           window.firstResponder === field || field.currentEditor() != nil {
            window.makeFirstResponder(nil)
            field.abortEditing()
        }
        field.delegate = nil
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
