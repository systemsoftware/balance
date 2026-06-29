import SwiftUI
import WebKit

struct ReaderView: View {
    let sourceWebView: WKWebView
    
    @State private var readerContent: String = ""
    @State private var readerTitle: String = "Reader Mode"
    @State private var isExtracting: Bool = true
    @State private var failedToExtract: Bool = false

    var body: some View {
        VStack {
            if isExtracting {
                ProgressView("Extracting Article...")
                    .padding()
            } else if failedToExtract {
                Text("Failed to extract article. This page might not be an article.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ReaderWebView(htmlContent: readerContent, baseURL: sourceWebView.url)
            }
        }
        .onAppear {
            extractArticle()
        }
        .navigationTitle(readerTitle)
    }
    
    private func extractArticle() {
        guard let readabilityJSUrl = Bundle.main.url(forResource: "Readability", withExtension: "js"),
              let readabilityJS = try? String(contentsOf: readabilityJSUrl, encoding: .utf8) else {
            print("Failed to load Readability.js from bundle")
            self.failedToExtract = true
            self.isExtracting = false
            return
        }
        
        let extractionJS = """
        (function() {
            try {
                \(readabilityJS)
                var documentClone = document.cloneNode(true);
                var article = new Readability(documentClone).parse();
                if (article) {
                    return { title: article.title, content: article.content };
                }
            } catch (e) {
                return { error: e.toString() };
            }
            return null;
        })();
        """
        
        sourceWebView.evaluateJavaScript(extractionJS) { result, error in
            DispatchQueue.main.async {
                self.isExtracting = false
                
                if let error = error {
                    print("JS Evaluation Error: \(error.localizedDescription)")
                    self.failedToExtract = true
                    return
                }
                
                if let dict = result as? [String: Any],
                   let html = dict["content"] as? String,
                   let title = dict["title"] as? String {
                    
                    self.readerTitle = title
                    
                    let styledHTML = """
                    <html>
                    <head>
                    <meta name="viewport" content="initial-scale=1.0" />
                    <style>
                        :root {
                            color-scheme: light dark;
                        }
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                            font-size: 18px;
                            line-height: 1.6;
                            color: var(--text-color);
                            background-color: var(--bg-color);
                            max-width: 700px;
                            margin: 0 auto;
                            padding: 2rem;
                        }
                        @media (prefers-color-scheme: light) {
                            body {
                                --text-color: #333;
                                --bg-color: #fff;
                            }
                        }
                        @media (prefers-color-scheme: dark) {
                            body {
                                --text-color: #eee;
                                --bg-color: transparent;
                            }
                            a { color: #4da6ff; }
                        }
                        img { max-width: 100%; height: auto; border-radius: 8px; }
                        figure { margin: 1em 0; }
                        figcaption { font-size: 0.9em; color: #888; text-align: center; }
                        h1, h2, h3 { line-height: 1.3; }
                        h1 { font-size: 2em; margin-bottom: 0.5em; }
                    </style>
                    </head>
                    <body>
                        <h1>\(title)</h1>
                        \(html)
                    </body>
                    </html>
                    """
                    self.readerContent = styledHTML
                } else {
                    if let dict = result as? [String: Any], let err = dict["error"] as? String {
                        print("Readability Error: \(err)")
                    }
                    self.failedToExtract = true
                }
            }
        }
    }
}

struct ReaderWebView: NSViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: baseURL)
    }
}
