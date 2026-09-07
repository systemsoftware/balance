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

    @AppStorage("showAddressBarAutofill") private var showAddressBarAutofill = true
    @State private var isFocused = false
    @State private var showSuggestions = false
    @State private var inputWidth: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            AddressTextField(
                text: $text,
                isFocused: $isFocused,
                focusOnAppear: focusOnAppear,
                onSubmit: {
                    showSuggestions = false
                    onSubmit()
                }
            )

            AddressSuggestionsPopover(
                isPresented: $showSuggestions,
                searchTerm: $text,
                width: inputWidth,
                onSelection: { showSuggestions = false },
                loadQuery: {
                    showSuggestions = false
                    onSubmit()
                }
            )
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .padding(10)
        .frame(height: 40)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { inputWidth = $0 }
        .onChange(of: text) { _, newValue in
            showSuggestions = shouldShowSuggestions(for: newValue)
        }
        .onChange(of: isFocused) { _, focused in
            showSuggestions = focused && shouldShowSuggestions(for: text)
        }
    }

    private func shouldShowSuggestions(for value: String) -> Bool {
        showAddressBarAutofill && isFocused && !value.isEmpty && !value.contains("//")
    }
}

private struct AddressSuggestionsPopover: NSViewRepresentable {
    @Binding var isPresented: Bool
    @Binding var searchTerm: String
    let width: CGFloat
    let onSelection: () -> Void
    let loadQuery: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let anchor = NSView()
        context.coordinator.anchor = anchor
        return anchor
    }

    func updateNSView(_ anchor: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateContent()

        if isPresented, !context.coordinator.popover.isShown, anchor.window != nil {
            context.coordinator.popover.show(
                relativeTo: anchor.bounds,
                of: anchor,
                preferredEdge: .minY
            )
        } else if !isPresented, context.coordinator.popover.isShown {
            context.coordinator.popover.performClose(nil)
        }
    }

    static func dismantleNSView(_ anchor: NSView, coordinator: Coordinator) {
        coordinator.popover.close()
    }

    final class Coordinator: NSObject, NSPopoverDelegate {
        var parent: AddressSuggestionsPopover
        weak var anchor: NSView?
        let popover = NSPopover()

        init(parent: AddressSuggestionsPopover) {
            self.parent = parent
            super.init()
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
        }

        func updateContent() {
            let content = AnyView(
                ScrollView {
                    AutocompleteView(
                        searchTerm: parent.$searchTerm,
                        onSelection: parent.onSelection,
                        loadQuery: parent.loadQuery
                    )
                }
                .padding()
                .frame(width: max(parent.width, 1), height: 300)
            )

            if let host = popover.contentViewController as? NSHostingController<AnyView> {
                host.rootView = content
            } else {
                popover.contentViewController = NSHostingController(rootView: content)
            }
            popover.contentSize = NSSize(width: max(parent.width, 1), height: 300)
        }

        func popoverDidClose(_ notification: Notification) {
            guard parent.isPresented else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.isPresented = false
            }
        }
    }
}

private struct AddressTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let focusOnAppear: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = "Search or enter website name"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.stringValue = text

        // AppKit's password-autofill heuristic can loop forever while walking a
        // SwiftUI popover's focus graph. The address bar supplies its own results.
        field.isAutomaticTextCompletionEnabled = false
        field.contentType = .URL
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
        var parent: AddressTextField
        var didFocus = false

        init(parent: AddressTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
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
