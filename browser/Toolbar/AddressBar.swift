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
    @FocusState private var isFocused: Bool
    @State private var showSuggestions = false
    @State private var fieldWidth: CGFloat = 300

    var body: some View {
        TextField("Search or enter website name", text: $text)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .autocorrectionDisabled()
            .onSubmit {
                showSuggestions = false
                onSubmit()
            }
            // Use .task so the view is fully in the hierarchy before focusing.
            // A small sleep is enough on macOS without needing DispatchQueue.
            .task(id: focusOnAppear) {
                guard focusOnAppear else { return }
                try? await Task.sleep(for: .milliseconds(50))
                isFocused = true
            }
            .onChange(of: text) { _, newValue in
                showSuggestions = shouldShowSuggestions(for: newValue)
            }
            .onChange(of: isFocused) { _, focused in
                showSuggestions = focused && shouldShowSuggestions(for: text)
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
        showAddressBarAutofill && isFocused && !value.isEmpty && !value.contains("//")
    }
}

