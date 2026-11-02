import SwiftUI
import WebKit

private struct OutlineHeading: Identifiable {
    let index: Int
    let level: Int
    let title: String

    var id: Int { index }
}

struct OutlineView: View {
    @ObservedObject var browserState: BrowserState

    @State private var headings: [OutlineHeading] = []
    @State private var articleTitle = ""
    @State private var isExtracting = false
    @State private var requestID = UUID()

    private static let readabilityJS: String = {
        guard let url = Bundle.main.url(forResource: "Readability", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return source
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outline")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(browserState.webView == nil || isExtracting)
                .help("Refresh outline")
            }
            .padding(16)

            if isExtracting {
                ProgressView("Finding headings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if headings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(browserState.webView == nil ? "Open a page to see its outline" : "No headings found")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if !articleTitle.isEmpty {
                            Text(articleTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 8)
                        }

                        ForEach(headings) { heading in
                            Button {
                                scrollToHeading(heading)
                            } label: {
                                Text(heading.title)
                                    .font(.system(.subheadline, design: .rounded,
                                                  weight: heading.level <= 2 ? .semibold : .regular))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, CGFloat(heading.level - 1) * 12)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.02))
        .task { refresh() }
        .onChange(of: browserState.isLoading) { _, loading in
            if loading {
                requestID = UUID()
                headings = []
                isExtracting = true
            } else {
                refresh()
            }
        }
        .onChange(of: browserState.url) { _, _ in
            if !browserState.isLoading { refresh() }
        }
        .onChange(of: browserState.webViewIdentity) { _, _ in refresh() }
    }

    private func refresh() {
        let id = UUID()
        requestID = id
        headings = []
        articleTitle = ""

        guard let webView = browserState.webView,
              webView.url != nil,
              !browserState.isLoading,
              !Self.readabilityJS.isEmpty else {
            isExtracting = browserState.isLoading
            return
        }

        isExtracting = true
        let script = Self.readabilityJS + "\n" + """
        (function() {
            try {
                const documentClone = document.cloneNode(true);
                documentClone.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
                    heading.setAttribute('data-balance-outline-index', String(index));
                });
                const article = new Readability(documentClone, { charThreshold: 1 }).parse();
                if (!article) return null;
                const content = document.createElement('div');
                content.innerHTML = article.content;
                const headings = Array.from(content.querySelectorAll('h1, h2, h3, h4, h5, h6'))
                    .filter(heading => heading.hasAttribute('data-balance-outline-index'))
                    .map(heading => ({
                        index: Number(heading.getAttribute('data-balance-outline-index')),
                        level: Number(heading.tagName.slice(1)),
                        title: (heading.textContent || '').replace(/\\s+/g, ' ').trim()
                    }))
                    .filter(heading => Number.isInteger(heading.index) &&
                        heading.index >= 0 && heading.title.length > 0);
                return { title: article.title || '', headings: headings };
            } catch (_) {
                return null;
            }
        })();
        """

        webView.evaluateJavaScript(script) { result, _ in
            DispatchQueue.main.async {
                guard requestID == id, browserState.webView === webView else { return }
                isExtracting = false
                guard let result = result as? [String: Any] else { return }
                articleTitle = result["title"] as? String ?? ""
                headings = (result["headings"] as? [[String: Any]] ?? []).compactMap { item in
                    guard let index = item["index"] as? Int,
                          let level = item["level"] as? Int,
                          let title = item["title"] as? String else { return nil }
                    return OutlineHeading(index: index, level: level, title: title)
                }
            }
        }
    }

    private func scrollToHeading(_ heading: OutlineHeading) {
        browserState.webView?.evaluateJavaScript("""
        document.querySelectorAll('h1, h2, h3, h4, h5, h6')[\(heading.index)]
            ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
        """, completionHandler: nil)
    }
}
