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

struct HourlyWeatherInfo: Identifiable {
    let id = UUID()

    var time: String
    var temperature: String
    var precip: String
    var pressure: String
    var condition: String
    var icon: String
    var visibility: String
    var wind: String
}

struct WeatherInfo {
    var temperature: String
    var precip: String
    var pressure: String
    var condition: String
    var icon: String
    var location: String
    var visibility: String
    var wind: String
    var hourly: [HourlyWeatherInfo]?
    var moon_phase: String
    var moon_rise_set: String
    var sun_rise_set: String
}

// MARK: - Stores / ViewModels

class ClockViewModel: ObservableObject {
    @Published var timeString = ""
    @Published var dateString = ""

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private var cancellable: AnyCancellable?

    init() {
        update()
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.update() }
    }

    private func update() {
        let now = Date()
        let time = Self.timeFormatter.string(from: now)
        let date = Self.dateFormatter.string(from: now)
        if timeString != time { timeString = time }
        if dateString != date { dateString = date }
    }
}

class WeatherViewModel: ObservableObject {

    @Published var weather: WeatherInfo?
    @Published var isLoading = true

    func fetch(city: String = "") {

        let query = city.isEmpty
            ? ""
            : city.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""

        let urlString = "https://wttr.in/\(query)?format=j1"

        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in

            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],

                let current = (json["current_condition"] as? [[String: Any]])?.first,
                let nearestArea = (json["nearest_area"] as? [[String: Any]])?.first
            else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            // MARK: - Current Weather

            let tempF = current["temp_F"] as? String ?? "?"

            let desc = (
                (current["weatherDesc"] as? [[String: Any]])?
                    .first?["value"] as? String
            ) ?? "Unknown"

            let code = current["weatherCode"] as? String ?? "113"

            let precip = current["precipInches"] as? String ?? ""

            let pressure = current["pressureInches"] as? String ?? ""

            let visibility = current["visibilityMiles"] as? String ?? ""

            let windDirection = current["winddir16Point"] as? String ?? ""

            let windSpeed = current["windspeedMiles"] as? String ?? ""

            let wind = "\(windDirection) \(windSpeed) mph"


            // MARK: - Location

            let areaName = (
                (nearestArea["areaName"] as? [[String: Any]])?
                    .first?["value"] as? String
            ) ?? ""

            let country = (
                (nearestArea["country"] as? [[String: Any]])?
                    .first?["value"] as? String
            ) ?? ""

            let location = [areaName, country]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")


            // MARK: - Daily Weather / Astronomy

            let today = (json["weather"] as? [[String: Any]])?.first

            let astronomy = (
                today?["astronomy"] as? [[String: Any]]
            )?.first

            let moonPhase = astronomy?["moon_phase"] as? String ?? ""

            let moonrise = astronomy?["moonrise"] as? String ?? ""
            let moonset = astronomy?["moonset"] as? String ?? ""

            let sunrise = astronomy?["sunrise"] as? String ?? ""
            let sunset = astronomy?["sunset"] as? String ?? ""

            let moonRiseSet = "\(moonrise) – \(moonset)"
            let sunRiseSet = "\(sunrise) – \(sunset)"


            // MARK: - Hourly Forecast

            let hourlyJSON = today?["hourly"] as? [[String: Any]] ?? []

                let hourly: [HourlyWeatherInfo] = hourlyJSON.map { hour in
                    
                    let hourTemp = hour["tempF"] as? String ?? "?"
                    
                    let hourDesc = (
                        (hour["weatherDesc"] as? [[String: Any]])?
                            .first?["value"] as? String
                    ) ?? "Unknown"
                    
                    let hourCode = hour["weatherCode"] as? String ?? "113"
                    
                    let hourPrecip = hour["precipInches"] as? String ?? ""
                    
                    let hourPressure = hour["pressureInches"] as? String ?? ""
                    
                    let hourVisibility = hour["visibilityMiles"] as? String ?? ""
                    
                    let hourWindDirection = hour["winddir16Point"] as? String ?? ""
                    let hourWindSpeed = hour["windspeedMiles"] as? String ?? ""
                    
                    let hourWind = "\(hourWindDirection) \(hourWindSpeed) mph"
                    
                    return HourlyWeatherInfo(
                        time: hour["time"] as? String ?? "t",
                        temperature: "\(hourTemp)°F",
                        precip: hourPrecip,
                        pressure: hourPressure,
                        condition: hourDesc,
                        icon: Self.icon(for: hourCode),
                        visibility: hourVisibility,
                        wind: hourWind
                    )
                }


            // MARK: - Publish

            DispatchQueue.main.async {

                self.weather = WeatherInfo(
                    temperature: "\(tempF)°F",
                    precip: precip,
                    pressure: pressure,
                    condition: desc,
                    icon: Self.icon(for: code),
                    location: location,
                    visibility: visibility,
                    wind: wind,
                    hourly: hourly,
                    moon_phase: moonPhase,
                    moon_rise_set: moonRiseSet,
                    sun_rise_set: sunRiseSet
                )

                self.isLoading = false
            }

        }.resume()
    }


    private static func icon(for code: String) -> String {

        switch code {

        case "113":
            return "sun.max.fill"

        case "116":
            return "cloud.sun.fill"

        case "119", "122":
            return "cloud.fill"

        case "143", "248", "260":
            return "cloud.fog.fill"

        case "176", "185", "293", "296", "299", "302", "305", "308":
            return "cloud.drizzle.fill"

        case "200", "386", "389", "392", "395":
            return "cloud.bolt.fill"

        case "227", "230":
            return "snow"

        case "263", "266":
            return "cloud.drizzle.fill"

        case "281", "284", "311", "314", "317", "320":
            return "cloud.sleet.fill"

        case "323", "326", "329", "332", "335", "338":
            return "snowflake"

        case "350", "353", "356", "359":
            return "cloud.heavyrain.fill"

        case "362", "365", "368", "371", "374", "377":
            return "cloud.snow.fill"

        default:
            return "cloud.fill"
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
        ("LA Times", "https://www.latimes.com/local/rss2.0.xml"),
        ("Mozilla", "https://hacks.mozilla.org/feed/"),
        ("NPR", "https://www.npr.org/rss/rss.php?id=1001"),
        ("Politico", "https://www.politico.com/rss/politicopicks.xml"),
        ("Reuters", "https://news.google.com/rss/search?q=site%3Areuters.com&hl=en-US&gl=US&ceid=US%3Aen"),
        ("The Economist", "https://www.economist.com/leaders/rss.xml"),
        ("The Guardian", "https://www.theguardian.com/world/rss"),
        ("The Hill", "https://thehill.com/news/feed/"),
        ("The New Yorker", "https://www.newyorker.com/feed/news"),
        ("NYT", "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml"),
        ("The Onion", "https://www.theonion.com/rss"),
        ("WSJ", "https://feeds.a.dj.com/rss/RSSWorldNews.xml"),
        ("Apple Developer", "https://developer.apple.com/news/rss/news.rss"),
        ("TechCrunch", "https://techcrunch.com/feed/"),
        ("Wired", "https://www.wired.com/feed/rss"),
        
    ]
    func fetch() {
        isLoading = true
        items = []
        guard sources.indices.contains(selectedSource) else {
            isLoading = false
            return
        }
        let selectedSource = sources[selectedSource]
        guard let url = URL(string: selectedSource.url) else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let xml = String(data: data, encoding: .utf8)
            else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            let parsed = Self.parseRSS(xml, source: selectedSource.name)
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

// MARK: - Shared styling

private extension View {
    /// Frosted container with a continuous corner and a hairline edge.
    func homeCard(cornerRadius: CGFloat = 20) -> some View {
        self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .padding(.leading, 4)
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - BookmarkCard

struct BookmarkCard: View {
    let bookmark: Bookmark
    @State private var isHovered = false

    var text = true

    var state: BrowserState

    var body: some View {
        Button {
            if let url = URL(string: bookmark.url) {
                state.navigate(to: url)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Favicon(bookmark.url, width: 34, height: 34)
                }
                .frame(width: 68, height: 68)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if text {
                    Text(bookmark.title)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .frame(width: 88)
            .scaleEffect(isHovered ? 1.04 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(TileButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .accessibilityLabel(bookmark.title)
    }
}

// MARK: - ClockView

struct ClockView: View {
    @StateObject private var vm = ClockViewModel()

    var timeOnly = false
    var fontSize: CGFloat = 72

    var body: some View {
        if timeOnly {
            Text(vm.timeString)
                .font(.system(size: fontSize, weight: .thin, design: .default).monospacedDigit())
                .contentTransition(.numericText())
        } else {
            // Lock-screen style: date above a large rounded time.
            VStack(spacing: 0) {
                Text(vm.dateString)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(vm.timeString)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: vm.timeString)
            }
            .multilineTextAlignment(.center)
        }
    }
}

// MARK: - WeatherView

struct WeatherView: View {
    @StateObject var vm: WeatherViewModel

    @AppStorage("homepageWeatherCity", store: Config.sharedDefaults) var weatherCity: String = ""

    @State var showMore = false
    
    var body: some View {
        Group {
            if vm.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading weather…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 96)
            } else if let w = vm.weather {
                content(for: w)
            } else {
                Text("Weather unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96)
            }
        }
        .homeCard(cornerRadius: 24)
        .onAppear { vm.fetch(city: weatherCity) }
    }

    private func content(for w: WeatherInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    if !w.location.isEmpty {
                        Text(w.location)
                            .font(.headline)
                    }
                    Text(w.temperature)
                        .font(.system(size: 52, weight: .light, design: .rounded))
                        .monospacedDigit()
                    Text(w.condition)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: w.icon)
                    .font(.system(size: 54))
                    .symbolRenderingMode(.multicolor)
            }

            DisclosureGroup("Forecast and Conditions", isExpanded: $showMore) {
                if let hourly = w.hourly, !hourly.isEmpty {
                    Divider()
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(hourly) { hour in
                                VStack(spacing: 8) {
                                    Text(Self.hourLabel(hour.time))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: hour.icon)
                                        .symbolRenderingMode(.multicolor)
                                        .font(.title3)
                                        .frame(height: 24)
                                    Text(hour.temperature.replacingOccurrences(of: "F", with: ""))
                                        .font(.subheadline.weight(.medium))
                                        .monospacedDigit()
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                
                Divider()
                
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 130), spacing: 16, alignment: .leading)],
                    alignment: .leading,
                    spacing: 14
                ) {
                    if !w.wind.trimmingCharacters(in: .whitespaces).isEmpty {
                        WeatherStat(title: "Wind", systemImage: "wind", value: w.wind)
                    }
                    if !w.precip.isEmpty {
                        WeatherStat(title: "Precipitation", systemImage: "drop.fill", value: "\(w.precip) in")
                    }
                    if !w.visibility.isEmpty {
                        WeatherStat(title: "Visibility", systemImage: "eye.fill", value: "\(w.visibility) mi")
                    }
                    if !w.pressure.isEmpty {
                        WeatherStat(title: "Pressure", systemImage: "gauge", value: "\(w.pressure) inHg")
                    }
                    if w.sun_rise_set.contains(where: \.isNumber) {
                        WeatherStat(title: "Sun", systemImage: "sunrise.fill", value: w.sun_rise_set)
                    }
                    if !w.moon_phase.isEmpty {
                        WeatherStat(title: "Moon", systemImage: "moon.stars.fill", value: w.moon_phase)
                    }
                }
            }
        }
        .padding(20)
    }

    /// wttr.in reports hourly blocks as "0", "300", … "2100".
    private static func hourLabel(_ raw: String) -> String {
        guard let value = Int(raw) else { return raw }
        let hour = value / 100
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(displayHour) \(hour < 12 ? "AM" : "PM")"
    }
}

private struct WeatherStat: View {
    let title: String
    let systemImage: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - NewsView

struct NewsView: View {
    @StateObject private var vm = NewsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Source picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.sources.indices, id: \.self) { i in
                        let isSelected = vm.selectedSource == i
                        Button {
                            vm.selectedSource = i
                            vm.fetch()
                        } label: {
                            Text(vm.sources[i].name)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    if isSelected {
                                        Capsule().fill(Color.appAccent)
                                    }
                                }
                                .glassEffect(isSelected ? .identity : .regular, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 1)
            }

            if vm.isLoading && vm.selectedSource != 0 {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if vm.items.isEmpty {
                Text(vm.selectedSource != 0 ? "Could not load news. Check your network connection." : "Choose a source above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .homeCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.items.enumerated()), id: \.element.id) { index, item in
                        NewsRow(item: item)
                        if index < vm.items.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .homeCard()
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
            if let url = URL(string: item.link) { createNewTab(with: url) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(item.source)
                            .fontWeight(.semibold)
                        if !item.pubDate.isEmpty {
                            Text(item.pubDate)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(isHovered ? 1 : 0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(isHovered ? 0.06 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Main BrowserHomepage

struct BrowserHomepage: View {
    var profile: String = ""
    @StateObject private var store = BookmarkStore()
    @State private var draggedCard: String?


    var state: BrowserState

    let columns = [GridItem(.adaptive(minimum: 96, maximum: 112), spacing: 12, alignment: .top)]

    
    @AppStorage("homepageShowDragHandles") var showDragHandles: Bool = true


    @State var showCityChange = false

    @StateObject private var weatherVM = WeatherViewModel()

    @AppStorage("profiles", store: Config.sharedDefaults) private var profilesJSON = "[]"

    @AppStorage("homepageShowWeather", store:Config.sharedDefaults) var showWeather: Bool = true
    @AppStorage("homepageShowBookmarks", store:Config.sharedDefaults) var showBookmarks: Bool = true
    @AppStorage("homepageShowEmail", store:Config.sharedDefaults) var showEmail: Bool = true
    @AppStorage("homepageShowStories", store:Config.sharedDefaults) var showStories: Bool = true
    @AppStorage("homepageShowCalendar", store:Config.sharedDefaults) var showCalendar: Bool = true
    @AppStorage("homepageWeatherCity", store: Config.sharedDefaults) var weatherCity = ""
    @AppStorage("homepageCardOrder", store: Config.sharedDefaults) private var cardOrder = "weather,bookmarks,email,stories,calendar"

    @State var falseBinding = false
    @Binding var location: URL?
    @Binding var urlInput: String
    var isPrivate: Bool = false
    var submitURL: () -> Void

    private var isEmailConfigured: Bool {
        let profiles = (try? JSONDecoder().decode([Profile].self, from: Data(profilesJSON.utf8))) ?? []
        let currentProfile = profiles.first { $0.id.uuidString == profile }
        return currentProfile?.imapHost != nil && !(currentProfile?.imapHost?.isEmpty ?? true)
    }

    @State private var date = Date()

    private static let defaultCardOrder = ["weather", "bookmarks", "email", "stories", "calendar"]

    private var orderedCards: [String] {
        let saved = cardOrder.split(separator: ",").map(String.init)
        let valid = saved.reduce(into: [String]()) { result, card in
            if Self.defaultCardOrder.contains(card), !result.contains(card) {
                result.append(card)
            }
        }
        return valid + Self.defaultCardOrder.filter { !valid.contains($0) }
    }

    private var visibleCards: [String] {
        orderedCards.filter { card in
            switch card {
            case "weather": return showWeather
            case "bookmarks": return showBookmarks
            case "email": return isEmailConfigured && showEmail
            case "stories": return showStories
            case "calendar": return showCalendar
            default: return false
            }
        }
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 40) {
                    hero
                    ForEach(visibleCards, id: \.self) { card in
                        homepageCard(card)
                            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                                guard draggedCard != nil, !providers.isEmpty else { return false }
                                moveCard(to: card)
                                return true
                            }
                    }
                }
                .frame(maxWidth: 820)
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 88)
                .frame(maxWidth: .infinity)
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) { customizeMenu }
        .sheet(isPresented: $showCityChange) { citySheet }
    }

    // MARK: Subviews

    var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
    
    var todaysDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    private var hero: some View {
        VStack {
            HStack {
                Text("Good \(timeOfDay).")
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                Spacer()
                Text(todaysDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            
            HStack(spacing: 10) {
                AddressBar(browserState: state, location: $location, urlInput: $urlInput, showTrustInfo: $falseBinding, focusOnAppear: false, isPrivate: isPrivate, profileIcon: "", profileName: "", submitURL: submitURL)
                
                Button(action: submitURL) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 26))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)
                .accessibilityLabel("Go")
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func homepageCard(_ card: String) -> some View {
        switch card {
        case "weather" where showWeather:
            VStack(alignment: .leading, spacing: 12) {
                draggableHeader("Weather", card: card)
                WeatherView(vm: weatherVM)
            }
        case "bookmarks" where showBookmarks:
            bookmarksSection
        case "email" where isEmailConfigured && showEmail:
            VStack(alignment: .leading, spacing: 12) {
                draggableHeader("Emails", card: card)
                EmailView(profile: profile, home: true)
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .homeCard()
            }
        case "stories" where showStories:
            VStack(alignment: .leading, spacing: 12) {
                draggableHeader("Recent Stories", card: card)
                NewsView()
            }
        case "calendar" where showCalendar:
            VStack(alignment: .leading, spacing: 12) {
                draggableHeader("Calendar", card: card)
                FullCalendarView(selectedDate: $date)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .homeCard()
            }
        default:
            EmptyView()
        }
    }

    private func draggableHeader(_ title: String, card: String) -> some View {
        HStack {
            SectionHeader(title: title)
            Spacer()
            if showDragHandles {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onDrag {
            draggedCard = card
            return NSItemProvider(object: card as NSString)
        }
        .accessibilityHint("Drag to reorder homepage cards")
    }

    private func moveCard(to target: String) {
        guard let draggedCard else { return }
        defer { self.draggedCard = nil }
        guard draggedCard != target else { return }
        var cards = orderedCards
        guard let sourceIndex = cards.firstIndex(of: draggedCard),
              let targetIndex = cards.firstIndex(of: target) else { return }
        cards.remove(at: sourceIndex)
        cards.insert(draggedCard, at: targetIndex)
        withAnimation(.easeInOut(duration: 0.2)) {
            cardOrder = cards.joined(separator: ",")
        }
    }

    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            draggableHeader("Bookmarks", card: "bookmarks")

            if store.items.isEmpty {
                emptyBookmarksState
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(store.items) { bookmark in
                        BookmarkCard(bookmark: bookmark, state: state)
                    }
                }
            }
        }
    }

    private var emptyBookmarksState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("No bookmarks yet")
                .font(.headline)
            Text("Add sites you visit often to open them from here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add Sample Bookmarks") { addSamples() }
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .homeCard()
    }

    private var customizeMenu: some View {
        Menu {
            Button {
                showCityChange = true
            } label: {
                Label("Change City", systemImage: "location")
            }
            
            Divider()
            
            Toggle("Show Drag Handles", isOn: $showDragHandles)
            
            Divider()

            Menu {
                Toggle("Weather", isOn: $showWeather)
                Toggle("Bookmarks", isOn: $showBookmarks)

                if isEmailConfigured {
                    Toggle("Email", isOn: $showEmail)
                }

                Toggle("News", isOn: $showStories)
                Toggle("Calendar", isOn: $showCalendar)
            } label: {
                Label("Views", systemImage: "square.grid.2x2")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .glassEffect(.regular, in: Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(20)
        .accessibilityLabel("Customize Homepage")
    }

    private var citySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set City for Weather")
                    .font(.headline)
                Text("Enter a city name, such as “Los Angeles” or “Palm Springs, CA”.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("City", text: $weatherCity)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveCity)

            HStack {
                Spacer()
                Button("Cancel") { showCityChange = false }
                    .tint(.primary)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: saveCity)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(weatherCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 400)
        .presentationDetents([.medium])
    }

    private func saveCity() {
        guard !weatherCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        showCityChange = false
        weatherVM.fetch(city: weatherCity)
    }

    private func addSamples() {
        store.add(Bookmark(title: "Google", url: "https://www.google.com"))
        store.add(Bookmark(title: "Wikipedia", url: "https://www.wikipedia.org"))
        store.add(Bookmark(title: "GitHub", url: "https://www.github.com"))
    }

}
