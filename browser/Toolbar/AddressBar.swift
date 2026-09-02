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

    @State private var suggestionsAnchor = NSView()

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

                AddressField(text: $urlInput, focusOnAppear: focusOnAppear, onSubmit: submitURL, suggestionsAnchor: suggestionsAnchor)
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
        .background(AddressBarAnchor(view: suggestionsAnchor))
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

private struct AddressBarAnchor: NSViewRepresentable {
    let view: NSView

    func makeNSView(context: Context) -> NSView {
        view.postsFrameChangedNotifications = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct AddressField: View {
    @Binding var text: String
    var focusOnAppear = false
    let onSubmit: () -> Void
    let suggestionsAnchor: NSView

    @AppStorage("showAddressBarAutofill") private var showAddressBarAutofill = true

    var body: some View {
        NativeAddressField(
            text: $text,
            onSubmit: onSubmit,
            focusOnAppear: focusOnAppear,
            showAutofill: showAddressBarAutofill,
            suggestionsAnchor: suggestionsAnchor
        )
        .padding(10)
    }
}

// Suggestions accept mouse input without taking the address field's keyboard focus.
private final class AddressSuggestionsPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct NativeAddressField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    var focusOnAppear = false
    var showAutofill = true
    let suggestionsAnchor: NSView

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        context.coordinator.field = field
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

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if let editor = field.currentEditor() {
            if editor.string != text {
                field.stringValue = text
                editor.string = text
            }
        } else if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.updateSuggestions()
        if focusOnAppear && !context.coordinator.didFocus {
            context.coordinator.didFocus = true
            let coordinator = context.coordinator
            DispatchQueue.main.async { [weak field, weak coordinator] in
                guard let field, let coordinator, !coordinator.isDismantled,
                      coordinator.parent.focusOnAppear,
                      field.currentEditor() == nil,
                      let window = field.window, window.isKeyWindow else { return }
                window.makeFirstResponder(field)
            }
        }
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        coordinator.closeSuggestions()
        coordinator.isDismantled = true
        field.delegate = nil
        if let window = field.window,
           window.firstResponder === field || field.currentEditor() != nil {
            window.makeFirstResponder(nil)
            field.abortEditing()
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeAddressField
        var didFocus = false
        var isDismantled = false
        weak var field: NSTextField?
        private var suggestionsPanel: AddressSuggestionsPanel?
        private var clickMonitor: Any?
        private var resignObserver: NSObjectProtocol?
        private var anchorObserver: NSObjectProtocol?

        func closeSuggestions() {
            if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
            clickMonitor = nil
            if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
            resignObserver = nil
            if let anchorObserver { NotificationCenter.default.removeObserver(anchorObserver) }
            anchorObserver = nil
            if let panel = suggestionsPanel {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            suggestionsPanel = nil
        }

        private func positionSuggestions() {
            guard let panel = suggestionsPanel,
                  let window = parent.suggestionsAnchor.window else { return }
            let view = parent.suggestionsAnchor
            let anchor = window.convertToScreen(view.convert(view.bounds, to: nil))
            let screen = window.screen?.visibleFrame ?? anchor
            let width = anchor.width
            let x = max(screen.minX, min(anchor.minX, screen.maxX - width))
            let y = anchor.minY - 310 >= screen.minY ? anchor.minY - 310 : anchor.maxY + 10
            panel.setFrame(NSRect(x: x, y: y, width: width, height: 300), display: true)
        }

        func updateSuggestions(showIfNeeded: Bool = false) {
            guard !isDismantled, parent.showAutofill,
                  !parent.text.isEmpty, !parent.text.contains("//"),
                  let field, field.currentEditor() != nil,
                  let window = field.window, window.isKeyWindow else {
                closeSuggestions()
                return
            }
            guard showIfNeeded || suggestionsPanel != nil else { return }

            let content = AnyView(
                List {
                    AutoFillView(searchTerm: parent.$text, onSelection: { [weak self] in
                        guard let self else { return }
                        if let field = self.field {
                            field.stringValue = self.parent.text
                            if let editor = field.currentEditor() {
                                editor.string = self.parent.text
                                editor.selectedRange = NSRange(location: (self.parent.text as NSString).length, length: 0)
                            }
                        }
                        self.closeSuggestions()
                    })
                    .listRowBackground(Color.clear)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            )

            if let host = suggestionsPanel?.contentView as? NSHostingView<AnyView> {
                host.rootView = content
                positionSuggestions()
                return
            }

            let panel = AddressSuggestionsPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = true
            panel.contentView = NSHostingView(rootView: content)
            suggestionsPanel = panel
            positionSuggestions()
            anchorObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification, object: parent.suggestionsAnchor, queue: .main
            ) { [weak self] _ in
                self?.positionSuggestions()
            }
            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)

            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else { return event }
                if event.window !== self.suggestionsPanel {
                    self.closeSuggestions()
                }
                return event
            }
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                self?.closeSuggestions()
            }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            closeSuggestions()
        }

        init(parent: NativeAddressField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
            updateSuggestions(showIfNeeded: true)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)), suggestionsPanel != nil {
                closeSuggestions()
                return true
            }
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            closeSuggestions()
            parent.onSubmit()
            return true
        }
    }
}
