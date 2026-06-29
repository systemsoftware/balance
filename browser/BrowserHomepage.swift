import SwiftUI
internal import Combine
internal import UniformTypeIdentifiers

// MARK: - Models

struct NewsItem: Identifiable {
    var id = UUID()
    var title: String
    var source: String
    var link: String
    var pubDate: String
}

struct WeatherInfo {
    var temperature: String
    var condition: String
    var icon: String
    var location: String
}

// MARK: - Stores / ViewModels

class ClockViewModel: ObservableObject {
    @Published var timeString = ""
    @Published var dateString = ""
    @Published var secondsFraction: Double = 0

    private var cancellable: AnyCancellable?

    init() {
        update()
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.update() }
    }

    private func update() {
        let now = Date()
        let tf = DateFormatter()
        tf.dateFormat = "h:mm"
        timeString = tf.string(from: now)

        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d"
        dateString = df.string(from: now)

        let cal = Calendar.current
        let seconds = cal.component(.second, from: now)
        secondsFraction = Double(seconds) / 60.0
    }
}

class WeatherViewModel: ObservableObject {
    @Published var weather: WeatherInfo?
    @Published var isLoading = true

    func fetch(city: String = "") {
        let query = city.isEmpty ? "" : city.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let urlString = "https://wttr.in/\(query)?format=j1"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = (json["current_condition"] as? [[String: Any]])?.first,
                  let nearestArea = (json["nearest_area"] as? [[String: Any]])?.first
            else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            let tempF = (current["temp_F"] as? [String])?.first
                       ?? (current["temp_F"] as? String) ?? "?"
            let desc = ((current["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String) ?? "Unknown"
            let code = (current["weatherCode"] as? String) ?? "113"

            let areaName = ((nearestArea["areaName"] as? [[String: Any]])?.first?["value"] as? String) ?? ""
            let country  = ((nearestArea["country"] as? [[String: Any]])?.first?["value"] as? String) ?? ""
            let location = [areaName, country].filter { !$0.isEmpty }.joined(separator: ", ")

            DispatchQueue.main.async {
                self.weather = WeatherInfo(
                    temperature: "\(tempF)°F",
                    condition: desc,
                    icon: Self.icon(for: code),
                    location: location
                )
                self.isLoading = false
            }
        }.resume()
    }

    private static func icon(for code: String) -> String {
        switch code {
        case "113": return "sun.max.fill"
        case "116": return "cloud.sun.fill"
        case "119", "122": return "cloud.fill"
        case "143", "248", "260": return "cloud.fog.fill"
        case "176", "185", "293", "296", "299", "302", "305", "308":
            return "cloud.drizzle.fill"
        case "200", "386", "389", "392", "395": return "cloud.bolt.fill"
        case "227", "230": return "snow"
        case "263", "266": return "cloud.drizzle.fill"
        case "281", "284", "311", "314", "317", "320": return "cloud.sleet.fill"
        case "323", "326", "329", "332", "335", "338": return "snowflake"
        case "350", "353", "356", "359": return "cloud.heavyrain.fill"
        case "362", "365", "368", "371", "374", "377": return "cloud.snow.fill"
        default: return "cloud.fill"
        }
    }
}

class NewsViewModel: ObservableObject {
    @Published var items: [NewsItem] = []
    @Published var isLoading = true
    @Published var selectedSource = 0

    let sources: [(name: String, url: String)] = [
        ("None", ""),
        ("BBC", "https://feeds.bbci.co.uk/news/rss.xml"),
        ("CNBC", "https://www.cnbc.com/id/100727362/device/rss/rss.html"),
        ("CNN", "https://rss.cnn.com/rss/cnn_topstories.rss"),
        ("LA Times", "https://www.latimes.com/local/rss2.0.xml"),
        ("Mozilla", "https://hacks.mozilla.org/feed/"),
        ("NPR", "https://www.npr.org/rss/rss.php?id=1001"),
        ("Politico", "https://www.politico.com/rss/politicopicks.xml"),
        ("Reuters", "https://news.google.com/rss/search?q=site%3Areuters.com&hl=en-US&gl=US&ceid=US%3Aen"),
        ("Economist", "https://www.economist.com/leaders/rss.xml"),
        ("Guardian", "https://www.theguardian.com/world/rss"),
        ("Hill", "https://thehill.com/news/feed/"),
        ("New Yorker", "https://www.newyorker.com/feed/news"),
        ("NYT", "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml"),
        ("Onion", "https://www.theonion.com/rss"),
        ("WSJ", "https://feeds.a.dj.com/rss/RSSWorldNews.xml"),
        ("WaPo", "https://feeds.washingtonpost.com/rss/homepage"),
        ("Apple Developer", "https://developer.apple.com/news/rss/news.rss"),
    ]
    func fetch() {
        isLoading = true
        items = []
        let urlString = sources[selectedSource].url
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let xml = String(data: data, encoding: .utf8)
            else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            let parsed = Self.parseRSS(xml, source: self.sources[self.selectedSource].name)
            DispatchQueue.main.async {
                self.items = parsed
                self.isLoading = false
            }
        }.resume()
    }

    private static func parseRSS(_ xml: String, source: String) -> [NewsItem] {
        var results: [NewsItem] = []
        let itemChunks = xml.components(separatedBy: "<item>").dropFirst()
        for chunk in itemChunks.prefix(12) {
            let title   = extract(tag: "title",   from: chunk)
            let link    = extract(tag: "link",    from: chunk)
            let pubDate = extract(tag: "pubDate", from: chunk)
            if !title.isEmpty {
                results.append(NewsItem(title: title, source: source, link: link, pubDate: shortDate(pubDate)))
            }
        }
        return results
    }

    private static func extract(tag: String, from string: String) -> String {
        guard let start = string.range(of: "<\(tag)>") ?? string.range(of: "<\(tag) "),
              let end   = string.range(of: "</\(tag)>", range: start.upperBound..<string.endIndex)
        else { return "" }
        var content = String(string[start.upperBound..<end.lowerBound])
        if content.hasPrefix("<![CDATA[") { content = String(content.dropFirst(9).dropLast(3)) }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shortDate(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: raw) {
            let out = DateFormatter()
            out.dateFormat = "MMM d · h:mm a"
            return out.string(from: date)
        }
        return raw
    }
}

// MARK: - BookmarkCard

struct BookmarkCard: View {
    let bookmark: Bookmark
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(isHovered ? 0.15 : 0.05))
                    .frame(width: 80, height: 80)

                AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(bookmark.url)&sz=64")) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFit().frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            Text(bookmark.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
        .frame(width: 120)
        .padding(.vertical, 10)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture {
            if let url = URL(string: bookmark.url) {
                createNewTab(with:url)
            }
        }
    }
}

// MARK: - ClockView

struct ClockView: View {
    @StateObject private var vm = ClockViewModel()

    var body: some View {
        VStack(spacing: 4) {
            Text(vm.timeString)
                .font(.system(size: 72, weight: .thin, design: .default).monospacedDigit())
                .contentTransition(.numericText())

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: geo.size.width * vm.secondsFraction)
                }
            }
            .frame(maxWidth: 160, maxHeight: 3)
            .animation(.linear(duration: 0.9), value: vm.secondsFraction)

            Text(vm.dateString)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - WeatherView

struct WeatherView: View {
    @StateObject private var vm = WeatherViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading weather…").foregroundColor(.secondary)
                }
            } else if let w = vm.weather {
                HStack(spacing: 14) {
                    Image(systemName: w.icon)
                        .font(.system(size: 28))
                        .symbolRenderingMode(.multicolor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.temperature)
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                        Text(w.condition)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        if !w.location.isEmpty {
                            Text(w.location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
          //      .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))
            } else {
                Text("Weather unavailable")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }
        }
        .onAppear { vm.fetch() }
    }
}

// MARK: - NewsView

struct NewsView: View {
    @StateObject private var vm = NewsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Source picker
            HStack(spacing: 0) {
                ForEach(vm.sources.indices, id: \.self) { i in
                    Button(vm.sources[i].name) {
                        vm.selectedSource = i
                        vm.fetch()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: vm.selectedSource == i ? .semibold : .regular))
                    .foregroundColor(vm.selectedSource == i ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(vm.selectedSource == i ? Color.primary.opacity(0.08) : .clear)
                    )
                }
            }

            if vm.isLoading && vm.selectedSource != 0 {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 30)
            } else if vm.items.isEmpty {
                Text( vm.selectedSource != 0 ? "Could not load news. Check network connection." : "Select a source.")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.items) { item in
                        NewsRow(item: item)
                        if item.id != vm.items.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
            }
        }
        .onAppear { vm.fetch() }
    }
}

struct NewsRow: View {
    let item: NewsItem
    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = URL(string: item.link) { createNewTab(with:url) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if !item.pubDate.isEmpty {
                        Text(item.pubDate)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(isHovered ? 0.05 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Main BrowserHomepage

struct BrowserHomepage: View {
    @StateObject private var store = BookmarkStore()
    @State private var searchText = ""

    let columns = [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 20)]
    
    
    @AppStorage("homeBackground", store:Config.sharedDefaults) var homeBackground: String = ""

    @State private var showingFilePicker = false
    @State private var showingURLPrompt = false
    @State private var urlString = ""
    
    
    var body: some View {
        ZStack {
            BackgroundImage(homeBackground:homeBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 50) {
                    
                    HStack(alignment: .top, spacing: 40) {
                        ClockView()
                    }
                    .padding(.top, 60)
                    
                    WeatherView()
                        .padding(.top, 8)
                    
                    
                    
                    if !store.items.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Bookmarks", systemImage: "bookmark.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                            
                            LazyVGrid(columns: columns, spacing: 30) {
                                ForEach(store.items) { bookmark in
                                    BookmarkCard(bookmark: bookmark)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                    } else {
                        emptyBookmarksState
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Top Stories", systemImage: "newspaper.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        NewsView()
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 600)
        .contextMenu {
            Menu("Background") {
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Add from File", systemImage: "folder")
                }

                Button {
                    urlString = homeBackground
                    showingURLPrompt = true
                } label: {
                    Label("Add from URL", systemImage: "link")
                }
                
                Divider()
                
                Button {
                    homeBackground = ""
                } label: {
                    Label("Remove", systemImage: "trash")
                }

            }
         }
        .sheet(isPresented: $showingURLPrompt) {
            NavigationStack {
                Form {
                    TextField("Image URL", text: $urlString)
                        .autocorrectionDisabled()
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .navigationTitle("Background URL")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingURLPrompt = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            homeBackground = urlString
                            showingURLPrompt = false
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image]
        ) { result in
            switch result {
            case .success(let url):
                homeBackground = url.absoluteString

            case .failure(let error):
                print(error)
            }
        }

    }

    // MARK: Subviews

    private var emptyBookmarksState: some View {
        VStack(spacing: 10) {
            Text("No bookmarks yet").foregroundColor(.secondary)
            Button("Add Sample Bookmarks") { addSamples() }.buttonStyle(.bordered)
        }
    }


    private func addSamples() {
        store.add(Bookmark(title: "GitHub",  url: "https://github.com"))
        store.add(Bookmark(title: "Apple",   url: "https://apple.com"))
        store.add(Bookmark(title: "SwiftUI", url: "https://developer.apple.com/xcode/swiftui/"))
        store.add(Bookmark(title: "HN",      url: "https://news.ycombinator.com"))
    }
    
    
}

// MARK: - Preview

struct BrowserHomepage_Previews: PreviewProvider {
    static var previews: some View {
        BrowserHomepage()
    }
}

struct BackgroundImage: View {
    let homeBackground: String

    var body: some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        if let url = URL(string: homeBackground),
           url.scheme?.hasPrefix("http") == true {

            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.clear
            }

        } else if
            let url = URL(string: homeBackground),
            let image = NSImage(contentsOf: url) {

            Image(nsImage: image)
                .resizable()
                .scaledToFill()

        } else {
            EmptyView()
        }
    }
}
