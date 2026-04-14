import SwiftUI
import WebKit
import Foundation

struct SidebarItem: Identifiable, Codable {
    var id = UUID()
    var icon: String
    var url: URL?
    var view: String?
}

struct SidebarStorage: Codable, RawRepresentable {
    var items: [SidebarItem]

    init(items: [SidebarItem]) {
        self.items = items
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([SidebarItem].self, from: data)
        else { return nil }
        self.items = decoded
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(items),
              let str = String(data: data, encoding: .utf8)
        else { return "[]" }
        return str
    }
}

let builtInSidebar = [
    SidebarItem(icon: "message", view: "ChatView"),
    SidebarItem(icon: "bookmark", view: "BookmarkView"),
]

struct ContentView: View {
    @State private var urlInput: String = ""
   
    @AppStorage("sidebar") var sidebarStorage = SidebarStorage(items: builtInSidebar)
    
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    private var sidebarWidth: Int = 300

    @EnvironmentObject var tabManager: TabManager

    @State private var sidebarURL: URL?

    @State private var showingSidebarAddAlert = false
    @State private var userInput = ""

    var body: some View {
        HStack {
            VStack {
                VStack(spacing: 0) {
                    // MARK: - Address Bar
                    HStack {
                        if let activePage = tabManager.tabs.first(where: { $0.id == tabManager.selectedTabID })?.page {
                            Button(action: {
                                Task {
                                    try await activePage.callJavaScript("history.back()")
                                }
                            }) {
                                Image(systemName: "chevron.backward")
                            }
                            //                 .disabled(activePage.backForwardList.backList.isEmpty)
                            
                            Button(action: {
                                Task {
                                    try await activePage.callJavaScript("history.forward()")
                                }
                            }) {
                                Image(systemName: "chevron.forward")
                            }
                            //             .disabled(activePage.backForwardList.forwardList.isEmpty)
                        }
                        TextField("Search or enter website name", text: $urlInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(submitURL)
                        
                        Button(action: submitURL) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    if !tabManager.tabs.isEmpty {
                        // MARK: - Tab Strip
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(tabManager.tabs) { tab in
                                    TabButton(
                                        tab: tab,
                                        isSelected: tabManager.selectedTabID == tab.id,
                                        onSelect: { tabManager.selectedTabID = tab.id },
                                        onClose: { tabManager.closeTab(id: tab.id) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 40)
                        .background(Color(NSColor.windowBackgroundColor))
                        
                        Divider()
                    }
                    
                    // MARK: - Web Content Area
                    ZStack {
                        if let activeTab = tabManager.tabs.first(where: { $0.id == tabManager.selectedTabID }) {
                            WebView(activeTab.page)
                                .transition(.opacity)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .onChange(of: activeTab.page.url) { oldValue, newValue in
                                    if let newURL = newValue {
                                        urlInput = newURL.absoluteString
                                    }
                                }
                        } else {
                            VStack {
                                Image(systemName: "browser.frame")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                                Text("No tabs open")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            
            // MARK: - Sidebar
            if !sidebarStorage.items.isEmpty {
                HStack {
                    if let sidebarURL {
                        if sidebarURL.absoluteString.contains(".view") {
                            if sidebarURL.absoluteString.contains("Chat") {
                                ChatView()
                                    .roundedBorderStyle()
                            } else if sidebarURL.absoluteString.contains("Bookmark") {
                                BookmarksView()
                                    .roundedBorderStyle()
                            }
                        } else {
                            WebView(url: sidebarURL)
                                .frame(width: CGFloat(sidebarWidth))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    VStack {
                        ForEach(sidebarStorage.items) { item in
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
                                        .frame(width: 20, height: 20)
                                        .padding(5)
                                } else {
                                    Image(systemName: item.icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .padding(5)
                                }
                            }
                            .contextMenu {
                                if sidebarStorage.items.count > 1 {
                                    Button("Remove", role: .destructive) {
                                        sidebarStorage.items.removeAll { $0.id == item.id }
                                    }
                                    Divider()
                                }
                                Button("Add remote page") {
                                    showingSidebarAddAlert = true
                                }
                                Menu("Add built-in"){
                                    ForEach(builtInSidebar) { builtIn in
                                        let title = builtIn.view?.replacingOccurrences(of: "View", with: "") ?? builtIn.icon
                                        
                                        Button(title, action: {
                                            guard let view = builtIn.view else { return }
                                            sidebarStorage.items.append(SidebarItem(icon: builtIn.icon, view: view))
                                        })
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .alert("Enter URL", isPresented: $showingSidebarAddAlert) {
                        TextField("URL", text: $userInput)
                        Button("OK") {
                            sidebarStorage.items.append(SidebarItem(
                                icon: "https://www.google.com/s2/favicons?domain=\(userInput)",
                                url: URL(string: userInput)!
                            ))
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                }
                .padding(5)
            }
        }
    }

    // MARK: - Helper Methods
    private func submitURL() {
        guard !urlInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        if tabManager.selectedTabID == nil || tabManager.tabs.isEmpty {
            tabManager.createNewTab(urlInput: urlInput)
        } else {
            tabManager.navigate(urlInput: urlInput)
        }

        urlInput = ""
    }
}

// MARK: - Subviews

struct TabButton: View {
    let tab: Tab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    private var title: String {
        tab.url.url?.host ?? tab.url.url?.absoluteString ?? "New Tab"
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}
