import SwiftUI
import MapKit
internal import Combine
import FoundationModels

private let model = SystemLanguageModel.default

class SearchCompleterManager: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completerResults: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
    }
    
    func updateSearch(query: String) {
        if query.isEmpty {
            completerResults = []
        } else {
            completer.queryFragment = query
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completerResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer failed: \(error.localizedDescription)")
    }
}

struct MapView: View {
    @State private var position: MapCameraPosition = .automatic
    @State private var searchText = ""
    @State private var searchResults: [PlaceItem] = []
    @State private var extractedPlaces: [PlaceItem] = []
    @State private var selectedResult: PlaceItem?
    
    @FocusState private var isSearchFocused: Bool
    
    @StateObject private var completerManager = SearchCompleterManager()
    
    @StateObject private var placeStore = PlaceStore()
        
    @State private var isScanning = false
    @State private var session: LanguageModelSession?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var browserState: BrowserState?
    
    var allPlaces: [PlaceItem] {
        let combined = placeStore.items + extractedPlaces + searchResults
        var unique: [String: PlaceItem] = [:]
        for item in combined {
            if unique[item.name] == nil {
                unique[item.name] = item
            }
        }
        return Array(unique.values)
    }
    
    var body: some View {
        Map(position: $position, selection: $selectedResult) {
            ForEach(allPlaces, id: \.id) { place in
                Annotation(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude), anchor: .bottom) {
                    let isPinned = placeStore.items.contains(where: { $0.id == place.id })
                    
                    VStack(spacing: -1) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isPinned ? Color.orange : Color.accentColor)
                                    .frame(width: 26, height: 26)
                                Image(systemName: isPinned ? "star.fill" : "mappin")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(place.name)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if let url = place.sourceURL, let host = URL(string: url)?.host {
                                    Text(host.replacingOccurrences(of: "www.", with: ""))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.trailing, 8)
                        }
                        .padding(4)
                        .background(Color(NSColor.windowBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        
                        Image(systemName: "triangle.fill")
                            .resizable()
                            .frame(width: 14, height: 7)
                            .rotationEffect(.degrees(180))
                            .foregroundColor(Color(NSColor.windowBackgroundColor))
                    }
                    .compositingGroup()
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 2)
                    .contextMenu {
                        if placeStore.items.contains(where: { $0.id == place.id }) {
                            Button("Remove Pin") {
                                placeStore.remove(id: place.id)
                            }
                        } else {
                            Button("Pin Place") {
                                placeStore.add(place)
                            }
                        }
                        
                        Divider()
                        
                        Button("Open in Maps") {
                            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                            let mapItem = MKMapItem(placemark: placemark)
                            mapItem.name = place.name
                            mapItem.openInMaps()
                        }
                    }
                }
                .tag(place)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium))
                    TextField("Search places...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { old, new in
                            completerManager.updateSearch(query: new)
                        }
                        .onSubmit {
                            search(for: searchText)
                            completerManager.completerResults = []
                        }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            completerManager.completerResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                
                if !completerManager.completerResults.isEmpty {
                    Divider().opacity(0.5)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(completerManager.completerResults, id: \.self) { result in
                                Button(action: {
                                    searchText = result.title
                                    search(from: result)
                                    completerManager.completerResults = []
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title).font(.system(size: 13, weight: .medium))
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle).font(.system(size: 11)).foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Divider().opacity(0.3)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                
                Divider().opacity(0.5)
                
                // Action Bar
                HStack {
                    if isScanning {
                        ProgressView().controlSize(.small)
                            .padding(.trailing, 4)
                        Text("Scanning tabs for places...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 20) {
                            Button(action: scanOpenTabs) {
                                HStack(spacing: 6) {
                                    Image(systemName: "wand.and.stars")
                                    Text("Scan All Tabs")
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                            
                            if browserState != nil {
                                Button(action: scanCurrentTab) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "rectangle.badge.sparkles")
                                        Text("Scan Tab")
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.02))
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding()
        }
        .simultaneousGesture(TapGesture().onEnded {
            isSearchFocused = false
            completerManager.completerResults = []
        })
        .onChange(of: selectedResult) { old, new in
            isSearchFocused = false
            completerManager.completerResults = []
            
            if let selected = new {
                position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: selected.latitude, longitude: selected.longitude), latitudinalMeters: 5000, longitudinalMeters: 5000))
            }
        }
        .alert("Scan Result", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func search(for query: String) {
        guard !query.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Error searching: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            searchResults = response.mapItems.compactMap { mapItem -> PlaceItem? in
                let mapName = mapItem.name ?? "Unknown"
                if mapName.isEmpty || mapName == "Unknown" { return nil }
                return PlaceItem(
                    name: mapName,
                    latitude: mapItem.location.coordinate.latitude,
                    longitude: mapItem.location.coordinate.longitude,
                    sourceURL: nil
                )
            }
            
            if let first = searchResults.first {
                position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude), latitudinalMeters: 5000, longitudinalMeters: 5000))
            }
        }
    }
    
    private func search(from completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Error searching completion: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            searchResults = response.mapItems.compactMap { mapItem -> PlaceItem? in
                let mapName = mapItem.name ?? "Unknown"
                if mapName.isEmpty || mapName == "Unknown" { return nil }
                return PlaceItem(
                    name: mapName,
                    latitude: mapItem.location.coordinate.latitude,
                    longitude: mapItem.location.coordinate.longitude,
                    sourceURL: nil
                )
            }
            
            if let first = searchResults.first {
                position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude), latitudinalMeters: 5000, longitudinalMeters: 5000))
            }
        }
    }
    
    enum ExtractionError: Error, LocalizedError {
        case invalidAIOutput(raw: String)
        case mkSearchFailed(names: [String])
        
        var errorDescription: String? {
            switch self {
            case .invalidAIOutput(let raw): return "AI output could not be parsed: \(raw)"
            case .mkSearchFailed(let names): return "MapKit failed to find any of: \(names.joined(separator: ", "))"
            }
        }
    }
    
    private static var aiExtractionCache: [String: [PlaceItem]] = [:]
    
    private func extractPlaces(from text: String, sourceURL: String?) async throws -> [PlaceItem] {
        if let url = sourceURL, let cached = MapView.aiExtractionCache[url] {
            return cached
        }
        
        let prompt = """
        You are an extraction bot. Find up to 3 specific points of interest (e.g. cities, restaurants, parks, museums, stores, landmarks) explicitly mentioned in the text. Do NOT extract broad states or countries.
        Output ONLY a comma-separated list of the names. No extra text, no markdown. If there are none, output exactly NONE.
        
        Example 1:
        Text: 'I went to Golden Gate Park and grabbed coffee at Blue Bottle.'
        Output: Golden Gate Park, Blue Bottle Coffee
        
        Example 2:
        Text: 'The weather is nice today in the city.'
        Output: NONE
        
        Text: '\(String(text.prefix(2500)))'
        Output:
        """
        
        

        let opts = GenerationOptions(
            sampling: .greedy,
            temperature: 0.0
        )
        
        session = LanguageModelSession()
        
        
        let result = try await session!.respond(to: prompt, options:opts).content
        let cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanResult.isEmpty || cleanResult == "NONE" {
            if let url = sourceURL { MapView.aiExtractionCache[url] = [] }
            return []
        }
        
        let names = cleanResult.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        if names.isEmpty {
            throw ExtractionError.invalidAIOutput(raw: cleanResult)
        }
        
        var items: [PlaceItem] = []
        for name in names {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = name
            let search = MKLocalSearch(request: req)
            if let response = try? await search.start(), let first = response.mapItems.first {
                let finalName = first.name ?? name
                if finalName.isEmpty || finalName == "Unknown" { continue }
                
                let item = PlaceItem(
                    name: finalName,
                    latitude: first.location.coordinate.latitude,
                    longitude: first.location.coordinate.longitude,
                    sourceURL: sourceURL
                )
                items.append(item)
            }
        }
        
        if items.isEmpty && !names.isEmpty {
            throw ExtractionError.mkSearchFailed(names: names)
        }
        
        if let url = sourceURL {
            MapView.aiExtractionCache[url] = items
        }
        
        return items
    }
    
    private func scanOpenTabs() {
        guard model.availability == .available else {
            print("Language model is not available.")
            return
        }
        
        isScanning = true
        extractedPlaces.removeAll()
        
        Task {
            var anyErrors: [String] = []
            var foundAnyItems = false
            
            for tab in WebExtensionManager.shared.allTabs {
                guard let webView = tab.webView else { continue }
                
                let text = await withCheckedContinuation { continuation in
                    DispatchQueue.main.async {
                        webView.getCleanText { result in
                            continuation.resume(returning: result ?? "")
                        }
                    }
                }
                
                guard !text.isEmpty else { continue }
                do {
                    let items = try await extractPlaces(from: text, sourceURL: tab.url?.absoluteString)
                    if !items.isEmpty { foundAnyItems = true }
                    
                    DispatchQueue.main.async {
                        for item in items {
                            if !self.extractedPlaces.contains(where: { $0.name == item.name }) {
                                self.extractedPlaces.append(item)
                            }
                        }
                    }
                } catch let error as ExtractionError {
                    anyErrors.append(error.localizedDescription)
                } catch {
                    anyErrors.append("AI Error: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.isScanning = false
                if self.extractedPlaces.isEmpty {
                    if !anyErrors.isEmpty {
                        self.alertMessage = anyErrors.first ?? "Unknown error occurred"
                    } else if !foundAnyItems {
                        self.alertMessage = "No POIs found in any open tabs."
                    } else {
                        self.alertMessage = "No new places were found in your open tabs."
                    }
                    self.showingAlert = true
                } else if let first = self.extractedPlaces.first {
                    self.position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude), latitudinalMeters: 5000, longitudinalMeters: 5000))
                }
            }
        }
    }
    
    private func scanCurrentTab() {
        guard model.availability == .available else {
            print("Language model is not available.")
            return
        }
        
        guard let webView = browserState?.webView else { return }
        let currentUrl = browserState?.url?.absoluteString
        
        isScanning = true
        extractedPlaces.removeAll()
        
        Task {
            let text = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    webView.getCleanText { result in
                        continuation.resume(returning: result ?? "")
                    }
                }
            }
            
            if !text.isEmpty {
                do {
                    let items = try await extractPlaces(from: text, sourceURL: currentUrl)
                    DispatchQueue.main.async {
                        self.extractedPlaces.append(contentsOf: items)
                        self.isScanning = false
                        
                        if items.isEmpty {
                            self.alertMessage = "No POIs found on this page."
                            self.showingAlert = true
                        } else if let first = items.first {
                            self.position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude), latitudinalMeters: 5000, longitudinalMeters: 5000))
                        }
                    }
                } catch let error as ExtractionError {
                    DispatchQueue.main.async {
                        self.alertMessage = error.localizedDescription
                        self.showingAlert = true
                        self.isScanning = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.alertMessage = "AI Error: \(error.localizedDescription)"
                        self.showingAlert = true
                        self.isScanning = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.alertMessage = "No text could be extracted from this tab."
                    self.showingAlert = true
                }
            }
        }
    }
}
