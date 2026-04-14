import Foundation
import SwiftUI
import WebKit
internal import Combine


struct Tab: Identifiable {
    let id = UUID()
    var page: WebPage
    var url: URLRequest
}

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

class TabManager: ObservableObject {

    @Published var tabs: [Tab] = []
    @Published var selectedTabID: UUID? = nil

    public func createNewTab(urlInput: String) {
        @AppStorage("searchEngine", store: Config.sharedDefaults)
        var searchEngine = "https://google.com/search?q="

        let defaultUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        @AppStorage("userAgent", store: Config.sharedDefaults)
        var userAgent = defaultUA

        guard let validURL = resolveURL(urlInput, searchEngine: searchEngine) else { return }

        let page = WebPage()
        page.customUserAgent = userAgent
        page.load(URLRequest(url: validURL))

        let newTab = Tab(page: page, url: URLRequest(url: validURL))
        tabs.append(newTab)
        selectedTabID = newTab.id
    }


    public func navigate(urlInput: String) {
        @AppStorage("searchEngine", store: Config.sharedDefaults)
        var searchEngine = "https://google.com/search?q="

        @AppStorage("userAgent", store: Config.sharedDefaults)
        var userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }),
              let validURL = resolveURL(urlInput, searchEngine: searchEngine) else {
            createNewTab(urlInput: urlInput)
            return
        }

        let request = URLRequest(url: validURL)
        tabs[index].url = request
        tabs[index].page.load(request)
    }

    public func closeTab(id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedTabID == id {
            selectedTabID = tabs.last?.id
        }
    }

    // MARK: - Private Helpers

    private func resolveURL(_ input: String, searchEngine: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if !trimmed.contains(" "), trimmed.contains(".") {
            if let url = URL(string: "https://\(trimmed)") {
                return url
            }
        }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "\(searchEngine)\(encoded)")
    }
}
