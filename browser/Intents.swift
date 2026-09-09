import AppIntents
import SwiftUI

struct BookmarkEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bookmark"
    static var defaultQuery = BookmarkEntityQuery()

    let id: String
    let title: String
    let url: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(url)"
        )
    }
}

struct SearchQueryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Query"
    static var defaultQuery = SearchQueryEntityQuery()

    let id: String
    let title: String
    let url: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(url)"
        )
    }
}

struct SearchQueryEntityQuery: EntityQuery, EntityStringQuery {

    @MainActor
    private func entity(for title: String) -> SearchQueryEntity {
        let engine = Config.sharedDefaults?.string(forKey: "searchURL") ?? "https://google.com/search?q="
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title

        return SearchQueryEntity(id: title, title: title, url: "\(engine)\(encodedTitle)")
    }
    
    @MainActor
    func entities(for identifiers: [SearchQueryEntity.ID]) async throws -> [SearchQueryEntity] {
        identifiers.map(entity(for:))
    }

    @MainActor
    func suggestedEntities() async throws -> [SearchQueryEntity] {
        let suggestions = AutocompleteStandalone.result?.suggestions ?? []
        return suggestions.map(entity(for:))
    }
    
    @MainActor
    func entities(matching string: String) async throws -> [SearchQueryEntity] {
        await AutocompleteStandalone.fetchSuggestions(for: string)

        return AutocompleteStandalone.result?.suggestions.map(entity(for:)) ?? []
    }
}

struct BookmarkEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [BookmarkEntity.ID]) async throws -> [BookmarkEntity] {
        let store = BookmarkStore()
        
        return store.items
            .filter { identifiers.contains($0.id.uuidString) }
            .map {
                BookmarkEntity(
                    id: $0.id.uuidString,
                    title: $0.title,
                    url: $0.url
                )
            }
    }
    
    
    @MainActor
    func entities(matching string: String) async throws -> [BookmarkEntity] {
        let store = BookmarkStore()
        
        return store.items
            .filter {
                $0.title.localizedCaseInsensitiveContains(string) ||
                $0.url.localizedCaseInsensitiveContains(string)
            }
            .map {
                BookmarkEntity(
                    id: $0.id.uuidString,
                    title: $0.title,
                    url: $0.url
                )
            }
    }
    
    @MainActor
    func suggestedEntities() async throws -> [BookmarkEntity] {
        let store = BookmarkStore()
        
        return store.items.map {
            BookmarkEntity(
                id: $0.id.uuidString,
                title: $0.title,
                url: $0.url
            )
        }
    }
}

struct CreateNewTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Bookmark in New Tab"
    
    @Parameter(title: "Bookmark")
    var bookmark: BookmarkEntity?
    
    static var openAppWhenRun = true
    
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$bookmark) in a new tab")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        
        if let bookmark {
            var string = bookmark.url
            
            if !string.contains("://") {
                string = "https://\(string)"
            }
            
            if let url = URL(string: string) {
                createNewTab(with: url)
            } else {
                createNewTab()
            }
        } else {
            createNewTab()
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        return .result()
    }
}

struct CreateNewWindowIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Bookmark in New Window"
    
    @Parameter(title: "Bookmark")
    var bookmark: BookmarkEntity?
    
    static var openAppWhenRun = true
    
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$bookmark) in a new window")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        
        if let bookmark {
            var string = bookmark.url
            
            if !string.contains("://") {
                string = "https://\(string)"
            }
            
            if let url = URL(string: string) {
                createNewWindow(with: url)
            } else {
                createNewWindow()
            }
        } else {
            createNewWindow()
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        return .result()
    }
}

struct OpenURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Open URL"

    @Parameter(title: "URL")
    var url: URL

    static var openAppWhenRun = true

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$url)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        createNewTab(with: url)
        return .result()
    }
}

struct AddBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Bookmark"

    @Parameter(title: "Title")
    var bookmarkTitle: String

    @Parameter(title: "URL")
    var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$bookmarkTitle) to bookmarks")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        BookmarkStore().add(Bookmark(title: bookmarkTitle, url: url.absoluteString))
        return .result()
    }
}

struct OpenPrivateWindowIntent: AppIntent {
    static var title: LocalizedStringResource = "New Private Window"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        createNewWindow(pvt: true)
        return .result()
    }
}

struct SearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Search"
    
    @Parameter(title: "Search Query")
    var q: SearchQueryEntity
    
    static var openAppWhenRun = true
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$q)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        
        if let url = URL(string:q.url) {
            createNewTab(with: url)
        } else {
            print("failed to open")
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        return .result()
    }
}


struct BrowserAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNewTabIntent(),
            phrases: [
                "Create a new tab in \(.applicationName)",
                "Open a new tab in \(.applicationName)",
                "Open bookmark \(\.$bookmark) in \(.applicationName)"
            ],
            shortTitle: "New Tab",
            systemImageName: "plus.square"
        )
        
        AppShortcut(intent: SearchIntent(), phrases: [
            "Search for \(\.$q) in \(.applicationName)",
        ], shortTitle: "Search", systemImageName: "magnifyingglass")

        AppShortcut(
            intent: OpenURLIntent(),
            phrases: [
                "Open URL in \(.applicationName)",
                "Open a URL in \(.applicationName)"
            ],
            shortTitle: "Open URL",
            systemImageName: "link"
        )

        AppShortcut(
            intent: AddBookmarkIntent(),
            phrases: [
                "Add a bookmark in \(.applicationName)",
                "Bookmark a URL in \(.applicationName)"
            ],
            shortTitle: "Add Bookmark",
            systemImageName: "bookmark.badge.plus"
        )

        AppShortcut(
            intent: OpenPrivateWindowIntent(),
            phrases: [
                "Open a private window in \(.applicationName)",
                "Create a private window in \(.applicationName)"
            ],
            shortTitle: "Private Window",
            systemImageName: "eye.slash"
        )
        
        AppShortcut(
            intent: CreateNewWindowIntent(),
            phrases: [
                "Create a new window in \(.applicationName)",
                "Open a new window in \(.applicationName)",
                "Open bookmark \(\.$bookmark) in a new window in \(.applicationName)"
            ],
            shortTitle: "New Window",
            systemImageName: "macwindow.badge.plus"
        )
    }
}
