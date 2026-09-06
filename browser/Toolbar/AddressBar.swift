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
    @FocusState private var isFocused: Bool
    @State private var showSuggestions = false
    @State private var inputWidth: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            TextField("Search or enter website name", text: $text)
                .textFieldStyle(.plain)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onSubmit {
                    showSuggestions = false
                    onSubmit()
                }

            Color.clear
                .frame(height: 1)
                .allowsHitTesting(false)
                .popover(isPresented: $showSuggestions, arrowEdge: .bottom) {
                    suggestions
                }
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
        .onAppear {
            guard focusOnAppear else { return }
            DispatchQueue.main.async { isFocused = true }
        }
    }

    private var suggestions: some View {
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
        .frame(width: inputWidth, height: 300)
    }

    private func shouldShowSuggestions(for value: String) -> Bool {
        showAddressBarAutofill && isFocused && !value.isEmpty && !value.contains("//")
    }
}
