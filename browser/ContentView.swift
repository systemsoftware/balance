import SwiftUI
import WebKit
import Foundation

// MARK: - Layout Constants
private enum Layout {
    static let outerPadding: CGFloat = 12
    static let controlPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 20
    static let sidebarIconSize: CGFloat = 20
    static let sidebarIconPadding: CGFloat = 8
    static let sidebarItemSpacing: CGFloat = 4
}

struct SidebarItem: Identifiable, Codable {
    var id = UUID()
    var icon: String
    var url: URL?
    var view: String?
}


let builtInSidebar = [
    SidebarItem(icon: "message", view: "ChatView"),
    SidebarItem(icon: "bookmark", view: "BookmarkView"),
    SidebarItem(icon: "gearshape.fill", view: "SettingsView"),
]

struct ContentView: View {
    @State private var urlInput: String = ""

    @StateObject private var sidebarStore = SidebarStore()

    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    private var sidebarWidth: Int = 300
    
    @AppStorage("userAgent", store:Config.sharedDefaults)
    private var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    
    @AppStorage("homepage", store: Config.sharedDefaults)
    private var homepage: String = "https://www.google.com"

    @State private var sidebarURL: URL?
    
    @State private var activePage = WebPage()

    @State private var showingSidebarAddAlert = false
    @State private var userInput = ""

    @Namespace private var searchNamespace
    @Namespace private var backforwardNamespace
    @Namespace private var sidebarNamespace

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Address Bar
            HStack(spacing: 8) {
                if activePage.url != nil {
                    GlassEffectContainer {
                        HStack(spacing: 0) {
                            Button(action: {
                                Task {
                                    try await activePage.callJavaScript("history.back()")
                                }
                            }) {
                                Image(systemName: "chevron.backward")
                                    .padding(Layout.controlPadding)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive())
                            .glassEffectUnion(id: "backforward", namespace: backforwardNamespace)

                            Button(action: {
                                Task {
                                    try await activePage.callJavaScript("history.forward()")
                                }
                            }) {
                                Image(systemName: "chevron.forward")
                                    .padding(Layout.controlPadding)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive())
                            .glassEffectUnion(id: "backforward", namespace: backforwardNamespace)
                        }
                    }

                    ShareLink(item: activePage.url!) {
                        Image(systemName: "square.and.arrow.up")
                            .padding(Layout.controlPadding)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    
                    Button(action: {
                        activePage.reload()
                    } ) {
                        Image(systemName: "arrow.clockwise")
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                }

                TextField("Search or enter website name", text: $urlInput)
                    .onSubmit(submitURL)
                    .padding(Layout.controlPadding)
                    .textFieldStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))

                HStack{
                    GlassEffectContainer {
                        HStack(spacing: 0) {
                            Button(action: submitURL) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .padding(Layout.controlPadding)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive())
                            .glassEffectUnion(id: "search", namespace: searchNamespace)
                        }
                    }
                    .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())
                }
            }
            .padding(.horizontal, Layout.outerPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)

            // MARK: - Web Content + Sidebar
            HStack(spacing: 0) {
                // MARK: - Web Content Area
                ZStack {
                    if ((activePage.url) != nil) {
                        WebView(activePage)
                            .transition(.opacity)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                            .onChange(of: activePage.url) { oldValue, newValue in
                                if let newURL = newValue {
                                    urlInput = newURL.absoluteString
                                }
                            }.onChange(of: activePage.title) { old, new in
                                if let window = NSApp.keyWindow {
                                    window.title = new
                                } else {
                                    print("no key window")
                                }
                            }                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            Text("No page open")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(Layout.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)


                // MARK: - Sidebar

                    HStack(spacing: 8) {
                        if let sidebarURL {
                            if sidebarURL.absoluteString.contains(".view") {
                                if sidebarURL.absoluteString.contains("Chat") {
                                    ChatView()
                                        .roundedBorderStyle()
                                } else if sidebarURL.absoluteString.contains("Bookmark") {
                                    BookmarksView()
                                        .roundedBorderStyle()
                                } else if (sidebarURL.absoluteString.contains("Settings")) {
                                    SettingsView()
                                        .roundedBorderStyle()
                                }
                            } else {
                                WebView(url: sidebarURL)
                                    .frame(width: CGFloat(sidebarWidth))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                            }
                        }

                        VStack(spacing: Layout.sidebarItemSpacing) {
                            GlassEffectContainer {
                                ForEach(sidebarStore.items) { item in
                                    Button(action: {
                                        let targetURL = item.url ?? URL(string: "\(item.view!).view")
                                        if sidebarURL == targetURL {
                                            sidebarURL = nil
                                        } else {
                                            sidebarURL = targetURL
                                        }
                                    }) {
                                        if item.icon.starts(with: "https") {
                                            AsyncImage(url: URL(string: item.icon))
                                                .frame(width: Layout.sidebarIconSize, height: Layout.sidebarIconSize)
                                                .padding(Layout.sidebarIconPadding)
                                        } else {
                                            Image(systemName: item.icon)
                                                .resizable()
                                                .frame(width: Layout.sidebarIconSize, height: Layout.sidebarIconSize)
                                                .padding(Layout.sidebarIconPadding)
                                        }
                                    }
                                    .glassEffect(.regular.interactive())
                                    .padding(1)
                                    .glassEffectUnion(id: "sidebar", namespace: sidebarNamespace)
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if sidebarStore.count() > 1 {
                                            Button("Remove", role: .destructive) {
                                                sidebarStore.remove(id: item.id)
                                            }
                                            Divider()
                                        }
                                        Button("Add remote page") {
                                            showingSidebarAddAlert = true
                                        }
                                        Menu("Add built-in") {
                                            ForEach(builtInSidebar) { builtIn in
                                                let title = builtIn.view?.replacingOccurrences(of: "View", with: "") ?? builtIn.icon
                                                Button(title, action: {
                                                    guard let view = builtIn.view else { return }
                                                    sidebarStore.add(SidebarItem(icon: builtIn.icon, view: view))
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .alert("Enter URL", isPresented: $showingSidebarAddAlert) {
                            TextField("URL", text: $userInput)
                            Button("OK") {
                                sidebarStore.add(SidebarItem(
                                    icon: "https://www.google.com/s2/favicons?domain=\(userInput)",
                                    url: URL(string: userInput)!
                                ))
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, Layout.outerPadding)
                    }
                    .padding(.trailing, Layout.outerPadding)
                    .padding(.vertical, Layout.outerPadding)
                }
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("Attempting to load homepage: \(homepage)")
                
                if homepage == "local-home" || homepage == "homepage" {
                    if let localURL = Bundle.main.url(forResource: "home", withExtension: "html") {
                            activePage.load(localURL)
                            urlInput = "about:home"
                        } else {
                            print("Error: home.html not found in bundle")
                        }
                        }
                
                            if let url = URL(string: homepage) {
                                activePage.load(url)
                                activePage.customUserAgent = userAgent
                                urlInput = homepage
                            } else {
                                print("Homepage URL was invalid: \(homepage)")
                            }
                        }
        }

    }

    // MARK: - Helper Methods
    private func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let url: URL?
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            url = URL(string: trimmed)
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)")
        } else if(trimmed == "homepage" || trimmed == "local-home") {
            url = Bundle.main.url(forResource: "home", withExtension: "html")
        } else {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "https://www.google.com/search?q=\(encoded)")
        }

        activePage.load(url)
        activePage.customUserAgent = userAgent
        urlInput = ""
    }
}
