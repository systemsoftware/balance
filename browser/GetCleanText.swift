import Foundation
import WebKit

extension WKWebView {

    private static let readabilityJS: String = {
        guard let url = Bundle.main.url(forResource: "Readability", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Readability.js not found in bundle")
            return ""
        }
        return source
    }()
    
    func getCleanArticle(completion: @escaping (ReadabilityResult?) -> Void) {
        guard !Self.readabilityJS.isEmpty else {
            completion(nil)
            return
        }

        let runner = """
        (function() {
            try {
                // Readability mutates the DOM it's given, so hand it a clone.
                var docClone = document.cloneNode(true);

                // Strip elements that commonly confuse extraction before parsing.
                docClone.querySelectorAll(
                    "script, style, noscript, iframe, svg, canvas, form, " +
                    "[aria-hidden='true'], .cookie, .cookie-banner, .paywall, .modal, .overlay"
                ).forEach(function(e) { e.remove(); });

                var article = new Readability(docClone, {
                    charThreshold: 200
                }).parse();

                if (!article || !article.textContent || article.textContent.trim().length < 100) {
                    return null;
                }

                var rawText = article.textContent || "";
                var cleanedTextContent = rawText.split('\\n')
                    .map(function(line) { return line.trim(); })
                    .join('\\n')
                    .replace(/\\n{3,}/g, '\\n\\n')
                    .trim();

                return {
                    title: article.title || "",
                    textContent: cleanedTextContent,
                    htmlContent: article.content || "",
                    excerpt: article.excerpt || "",
                    byline: article.byline || "",
                    siteName: article.siteName || "",
                    length: article.length || 0
                };
            } catch (e) {
                return { error: String(e) };
            }
        })();
        """

        let fullScript = Self.readabilityJS + "\n" + runner

        self.evaluateJavaScript(fullScript) { result, error in
            if let error = error {
                print("getCleanArticle JS error:", error)
                completion(nil)
                return
            }

            guard let dict = result as? [String: Any] else {
                completion(nil)
                return
            }

            if let jsError = dict["error"] as? String {
                print("Readability.js threw:", jsError)
                completion(nil)
                return
            }

            let article = ReadabilityResult(
                title: dict["title"] as? String ?? "",
                textContent: dict["textContent"] as? String ?? "",
                htmlContent: dict["htmlContent"] as? String ?? "",
                excerpt: dict["excerpt"] as? String ?? "",
                byline: dict["byline"] as? String ?? "",
                siteName: dict["siteName"] as? String ?? ""
            )

            completion(article.textContent.isEmpty ? nil : article)
        }
    }

    func getCleanText(completion: @escaping (String?) -> Void) {
        getCleanArticle { article in
            guard let article = article else {
                completion(nil)
                return
            }
            let fullText = "\(article.title)\n\n\(article.textContent)"
            completion(fullText)
        }
    }
}

struct ReadabilityResult {
    let title: String
    let textContent: String
    let htmlContent: String
    let excerpt: String
    let byline: String
    let siteName: String
}
