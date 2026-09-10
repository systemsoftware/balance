import SwiftUI
import WebKit
internal import UniformTypeIdentifiers

struct RSSView: View {
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345
    
    @State private var errorMessage: String?
    
    @AppStorage("rssFeeds", store: Config.sharedDefaults) private var rssFeedsStr =  "[]"
        
    private var parsedRSSFeeds: [String] {
        get {
            (try? JSONDecoder().decode([String].self,
                                       from: Data(rssFeedsStr.utf8))) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let encoded = String(data: data, encoding: .utf8) else { return }
            rssFeedsStr = encoded
        }
    }
    
    @State var searchText = ""
    
    @State var url = ""
    @State private var isAddingFeed = false
    @State private var newFeedURL = ""
        
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text("RSS Feeds")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                
                Button() {
                    newFeedURL = ""
                    isAddingFeed = true
                } label: {
                    Label("Add Feed", systemImage: "link")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.bottom, 8)
            
            // MARK: - Feeds List
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if parsedRSSFeeds.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No Feeds")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Click 'Add Feed' to add a source")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(parsedRSSFeeds, id: \.self) { section in
                            DisclosureRow(url: section)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteFeed(section)
                                    } label: {
                                        Label("Delete Feed", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding()
        .alert("Add RSS Feed", isPresented: $isAddingFeed) {
            TextField("https://example.com/feed", text: $newFeedURL)
            Button("Cancel", role: .cancel) {}
            Button("Add") { addFeed(newFeedURL) }
                .disabled(newFeedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter the URL of an RSS feed")
        }
    }
    
    private func deleteFeed(_ feedURL: String) {
        var feeds = loadFeeds()
        feeds.removeAll { $0 == feedURL }
        saveFeeds(feeds)
    }
    
    private func addFeed(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var feeds = loadFeeds()
        feeds.append(value)
        saveFeeds(feeds)
    }
    
    
    private func loadFeeds() -> [String] {
        (try? JSONDecoder().decode([String].self,
                                   from: Data(rssFeedsStr.utf8))) ?? []
    }

    private func saveFeeds(_ feeds: [String]) {
        guard let data = try? JSONEncoder().encode(feeds),
              let encoded = String(data: data, encoding: .utf8) else { return }
        rssFeedsStr = encoded
    }
    
    }


struct DisclosureRow: View {
    @State private var isExpanded = false
    
    var url: String
    
    @State var rssItems: [RSSItem] = []
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(rssItems, id: \.self) { item in
                Button {
                    createNewTab(with: URL(string: item.link))
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(item.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.platformControlBackground)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        } label: {
            Text(URL(string:url)?.host ?? url)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
        }
        .onChange(of: isExpanded) { _, isOpen in
            if isOpen {
                loadFeed()
            }
        }
    }
    
    private func loadFeed() {
        Task {
            if let u = URL(string:url) {
                rssItems = await RSSParser().parseFeed(from: u)
            }
        }
    }

}
