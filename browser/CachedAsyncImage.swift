import SwiftUI

func FirstLetterOfURL(url: URL?) -> String {
    guard let url else {
        return "?"
    }

    guard var host = url
        .deletingPathExtension()
        .lastPathComponent
        .removingPercentEncoding,
        !host.isEmpty
    else {
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

struct Favicon: View {
    
    var url: String
    
    var width: CGFloat = 16
    var height: CGFloat = 16
    
    static func full(_ urlString: String) -> URL? {
        let normalized = urlString.contains("://")
            ? urlString
            : "https://\(urlString)"

        guard let host = URL(string: normalized)?.host else {
            return nil
        }

        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }
    
    init(_ url: String, width: CGFloat = 16, height: CGFloat = 16) {
        self.url = url
        self.width = width
        self.height = height
    }
    
    var body: some View {
        CachedAsyncImage(url:Favicon.full(url))
            .frame(width: width, height: height)
    }
    
}

struct CachedAsyncImage: View {
    
    @AppStorage("loadImages") private var loadImages = true

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
                .onAppear {
                    print("Failed to get first letter of URL: \(url?.absoluteString ?? "nil")")
                }
        } else {
            Text(first)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}
