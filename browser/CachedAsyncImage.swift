import SwiftUI

func FirstLetterOfURL(url: URL?) -> String {
    guard
        let url,
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let domain = components.queryItems?
            .first(where: { $0.name == "domain" })?
            .value
    else {
        return "?"
    }

    let normalized = domain.contains("://")
        ? domain
        : "https://\(domain)"

    guard var host = URL(string: normalized)?.host else {
        return "?"
    }

    if host.hasPrefix("www.") {
        host.removeFirst(4)
    }

    guard let first = host.first else {
        return "?"
    }

    return String(first).uppercased()
}

struct CachedAsyncImage: View {
    @AppStorage("loadImages") var loadImages = true

    var url: URL?

    var body: some View {
        Group {
            if loadImages {
                CachedAsyncImageCore(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else if phase.error != nil {
                      fallbackView
                    } else {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
            } else {
                fallbackView
            }
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        
        let first = FirstLetterOfURL(url: url)
        
        if first == "?" {
            Image(systemName: "globe")
        } else {
            Text(FirstLetterOfURL(url: url))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}
