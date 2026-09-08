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
            TrustIndicator(url: location, isPresented: $showTrustInfo)
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

// MARK: - Trust Indicator

private struct TrustIndicator: View {
    let url: URL?
    @Binding var isPresented: Bool

    private var isWebURL: Bool {
        url?.scheme == "http" || url?.scheme == "https"
    }

    private var isSecure: Bool {
        url?.scheme == "https"
    }

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            Image(systemName: isSecure ? "lock.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isSecure ? Color.primary : Color.red)
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
            if !isWebURL { isPresented = false }
        }
    }
}

// MARK: - Address Field

private struct AddressField: View {
    @Binding var text: String
    var focusOnAppear = false
    let onSubmit: () -> Void

    @AppStorage("showAddressBarAutofill") private var showAddressBarAutofill = true
    @State private var isEditing = false
    @State private var showSuggestions = false
    @State private var fieldWidth: CGFloat = 300

    var body: some View {
        NativeAddressTextField(
            text: $text,
            focusOnAppear: focusOnAppear,
            onEditingChange: { editing in
                isEditing = editing
                showSuggestions = editing && shouldShowSuggestions(for: text)
            },
            onSubmit: {
                showSuggestions = false
                onSubmit()
            }
        )
            .onChange(of: text) { _, newValue in
                showSuggestions = shouldShowSuggestions(for: newValue)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fieldWidth = $0 }
            .popover(isPresented: $showSuggestions, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                ScrollView {
                    AutocompleteView(
                        searchTerm: $text,
                        onSelection: { showSuggestions = false },
                        loadQuery: {
                            showSuggestions = false
                            onSubmit()
                        }
                    )
                }
                .padding()
                .frame(width: max(fieldWidth, 1), height: 300)
            }
            .padding(10)
            .frame(height: 40)
    }

    private func shouldShowSuggestions(for value: String) -> Bool {
        showAddressBarAutofill && isEditing && !value.isEmpty && !value.contains("//")
    }
}

private final class AddressNSTextField: NSTextField {
    // macOS 27's password-autofill heuristic asks the focused field for its
    // neighboring valid key views. Crossing into SwiftUI's responder graph can
    // loop forever, so the address field explicitly ends both traversals.
    override var previousValidKeyView: NSView? { nil }
    override var nextValidKeyView: NSView? { nil }
}

private struct NativeAddressTextField: NSViewRepresentable {
    @Binding var text: String
    let focusOnAppear: Bool
    let onEditingChange: (Bool) -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = AddressNSTextField()
        field.delegate = context.coordinator
        field.placeholderString = "Search or enter website name"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.isAutomaticTextCompletionEnabled = false
        field.contentType = .URL
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }

        guard focusOnAppear, !context.coordinator.didFocus else { return }
        context.coordinator.didFocus = true
        DispatchQueue.main.async { [weak field] in
            guard let field, field.window?.isKeyWindow == true else { return }
            field.window?.makeFirstResponder(field)
        }
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        field.delegate = nil
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeAddressTextField
        var didFocus = false

        init(parent: NativeAddressTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.onEditingChange(true)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onEditingChange(false)
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
