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
    var iconURL: URL?
    var debounce = false
    @State private var settledURL: String?
    
    static func full(_ urlString: String) -> URL? {
        let normalized = urlString.contains("://")
            ? urlString
            : "https://\(urlString)"

        guard let host = URL(string: normalized)?.host else {
            return nil
        }

        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }
    
    init(_ url: String, width: CGFloat = 16, height: CGFloat = 16, iconURL: URL? = nil, debounce: Bool = false) {
        self.url = url
        self.width = width
        self.height = height
        self.iconURL = iconURL
        self.debounce = debounce
    }
    
    var body: some View {
        CachedAsyncImage(url: iconURL ?? Favicon.full(debounce ? (settledURL ?? "") : url))
            .frame(width: width, height: height)
            .compositingGroup()
            .clipShape(Circle())
            .task(id: debounce ? url : "") {
                guard debounce else { return }
                if url.isEmpty {
                    settledURL = nil
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                settledURL = url
            }
    }
    
}

struct CachedAsyncImage: View {
    
    @AppStorage("loadImages") private var loadImages = true

    var url: URL?

    var body: some View {
        Group {
            if let url = url {
                if loadImages || url.absoluteString.contains("failed-favicon") {
                    CachedAsyncImageCore(url: url) { phase, isMonochromeIcon in
                        if let image = phase.image {
                            image
                                .renderingMode(isMonochromeIcon ? .template : .original)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.primary)
                        } else if phase.error != nil {
                            fallbackView
                        } else {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
                    .id(url)
                } else {
                    fallbackView
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
