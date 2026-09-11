import SwiftUI
import WebKit

struct AddressBar: View {
    @ObservedObject var browserState: BrowserState
    @Binding var location: URL?
    @Binding var urlInput: String
    @Binding var showTrustInfo: Bool

    let focusOnAppear: Bool
    let isPrivate: Bool
    let profileIcon: String?
    let profileName: String?
    let submitURL: () -> Void
    @AppStorage("toolbarLocation") private var toolbarLocation = 0

    var body: some View {
        HStack {
            TrustIndicator(url: location, isPresented: $showTrustInfo)
                .popover(
                    isPresented: $showTrustInfo,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: toolbarLocation == 0 ? .top : .bottom
                ) {
                    ServerTrustView(
                        trust: browserState.serverTrust,
                        url: location,
                        webView: browserState.webView,
                        dataStore: browserState.webView?.configuration.websiteDataStore,
                        onAttemptHTTPS: attemptHTTPS
                    )
                    .roomyToolbarPopover()
                }

            AddressField(
                text: $urlInput,
                isLoading: browserState.isLoading,
                focusOnAppear: focusOnAppear,
                onSubmit: submitURL
            )
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
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipped()
    //    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
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
    let isLoading: Bool
    var focusOnAppear = false
    let onSubmit: () -> Void

    @AppStorage("showAddressBarAutofill") private var showAddressBarAutofill = true
    @State private var isEditing = false
    @State private var showSuggestions = false
    @State private var fieldWidth: CGFloat = 300
    @AppStorage("toolbarLocation") private var toolbarLocation = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Search or enter website name", text: $text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled(true)
            .lineLimit(1)
#if os(iOS)
            .textInputAutocapitalization(.never)
            .submitLabel(.go)
#endif
            .focused($isFocused)
            .onSubmit {
                showSuggestions = false
                onSubmit()
            }
            .onAppear {
                if focusOnAppear { isFocused = true }
            }
            .onChange(of: isFocused) { _, editing in
                isEditing = editing
                showSuggestions = editing && shouldShowSuggestions(for: text)
                if !editing { showSuggestions = false }
            }
            .onChange(of: isLoading) { wasLoading, isLoading in
                if wasLoading && !isLoading {
                    isFocused = false
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .onChange(of: text) { _, newValue in
                showSuggestions = shouldShowSuggestions(for: newValue)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fieldWidth = $0 }
            .popover(
                isPresented: $showSuggestions,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: toolbarLocation == 0 ? .top : .bottom
            ) {
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
#if os(iOS)
                .presentationCompactAdaptation(.popover)
#endif
            }
            .padding(10)
            .frame(height: 40)
    }

    private func shouldShowSuggestions(for value: String) -> Bool {
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return showAddressBarAutofill && isEditing && !query.isEmpty && !query.contains("//")
    }
}
