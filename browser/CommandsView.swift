import SwiftUI
import WebKit
import SwiftData

internal import UniformTypeIdentifiers

// MARK: - Sections

enum CommandSection: String, CaseIterable, Identifiable, Codable {
    case tabs, bookmarks, search, commands, history
    var id: String { rawValue }

    var title: String {
        switch self {
        case .tabs: "Tabs"
        case .bookmarks: "Bookmarks"
        case .search: "Search"
        case .commands: "Commands"
        case .history: "History"
        }
    }

    var symbol: String {
        switch self {
        case .tabs: "macwindow"
        case .bookmarks: "bookmark"
        case .search: "magnifyingglass"
        case .commands: "command"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct SectionDropDelegate: DropDelegate {
    let item: CommandSection
    @Binding var items: [CommandSection]
    @Binding var draggedItem: CommandSection?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = self.draggedItem,
              draggedItem != item,
              let from = items.firstIndex(of: draggedItem),
              let to = items.firstIndex(of: item) else {
            return
        }

        withAnimation {
            self.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
}

// MARK: - Models

struct Command: Identifiable {
    enum Action {
        case newTab
        case newWindow
        case newPrivateWindow
        case newWindowAt
        case newPrivateWindowAt
        case newWindowWithProfile
        case newProfile
    }

    let id = UUID()
    let name: String
    let systemImage: String
    let action: Action
    let showsChevron: Bool
    var subtitle: String? = nil

    var isPrivate: Bool {
        action == .newPrivateWindow || action == .newPrivateWindowAt
    }
}

struct Profile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var imapHost: String?
    var imapPort: UInt16?
    var isEphemeral: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, imapHost, imapPort, isEphemeral
    }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "person.crop.circle",
        isEphemeral: Bool = false,
        imapHost: String? = nil,
        imapPort: UInt16? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.isEphemeral = isEphemeral
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        imapHost = try container.decodeIfPresent(String.self, forKey: .imapHost)
        imapPort = try container.decodeIfPresent(UInt16.self, forKey: .imapPort)
        isEphemeral = try container.decodeIfPresent(Bool.self, forKey: .isEphemeral) ?? false
    }
}

/// One selectable line in the palette, whatever it came from.
private struct PaletteItem: Identifiable {
    enum Kind {
        case tab(BrowserState)
        case bookmark(Bookmark)
        case history(HistoryItem)
        case command(Command)
    }

    let id: String
    let title: String
    let subtitle: String?
    let symbol: String
    let host: String?
    let kind: Kind
    var showsChevron = false
    var isPrivate = false
}

private struct ResultGroup: Identifiable {
    let section: CommandSection
    var items: [PaletteItem]
    var canToggle = false
    var id: String { section.rawValue }
}

/// Bolds the parts of `text` that match the search words.
private func highlighted(_ text: String, term: String) -> AttributedString {
    var attributed = AttributedString(text)
    for word in term.split(whereSeparator: \.isWhitespace) {
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let found = attributed[searchRange].range(
            of: String(word),
            options: [.caseInsensitive, .diacriticInsensitive]
        ) {
            attributed[found].inlinePresentationIntent = .stronglyEmphasized
            searchRange = found.upperBound..<attributed.endIndex
        }
    }
    return attributed
}

// MARK: - Shared pieces

/// Rounded square that holds an SF Symbol. Used for every row in the palette and profile screens.
struct PaletteIconTile: View {
    let symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                tint.opacity(0.14),
                in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            )
    }
}

@ViewBuilder
func row(
    title: String,
    image: String,
    showsChevron: Bool = false
) -> some View {
    HStack(spacing: 12) {
        PaletteIconTile(symbol: image, tint: .secondary)

        Text(title)

        Spacer()

        if showsChevron {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
    .padding(.vertical, 4)
}

private struct PaletteSectionHeader: View {
    let section: CommandSection
    let count: Int
    let canToggle: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    @Binding var order: [CommandSection]
    @Binding var dragging: CommandSection?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if canToggle {
                Button(isExpanded ? "Show fewer" : "Show more", action: onToggle)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }

            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(isHovering ? 1 : 0)
                .help("Drag to reorder sections")
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onDrag {
            dragging = section
            return NSItemProvider(object: section.rawValue as NSString)
        }
        .onDrop(
            of: [.plainText],
            delegate: SectionDropDelegate(item: section, items: $order, draggedItem: $dragging)
        )
    }
}

private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool
    let term: String
    let onHover: () -> Void
    let onActivate: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 1) {
                Text(highlighted(item.title, term: term))
                    .lineLimit(1)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color.accentColor.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onActivate)
        .onHover { hovering in
            isHovering = hovering
            if hovering { onHover() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var leading: some View {
        if let host = item.host, !host.isEmpty {
            Favicon(host)
                .frame(width: 28, height: 28)
        } else {
            PaletteIconTile(
                symbol: item.symbol,
                tint: item.isPrivate ? .purple : .accentColor
            )
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let onClose, isHovering {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderless)
            .help("Close tab")
        } else if item.showsChevron {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        } else if isSelected {
            Image(systemName: "return")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Palette

struct CommandsView: View {
    enum Screen: Equatable {
        case commands
        case profiles
        case enterURL(privateMode: Bool)
    }

    private enum Field { case search, url }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    @State private var screen: Screen = .commands
    @Binding var searchText: String

    @Query(sort: \HistoryItem.timestamp, order: .reverse)
    private var historyItems: [HistoryItem]

    @State private var bookmarkStore = BookmarkStore()

    /// `false` shows the arrange-and-hide list used by settings instead of live results.
    var showData = true

    let commands: [Command] = [
        .init(name: "New Tab",
              systemImage: "plus.square.on.square",
              action: .newTab, showsChevron: false,
              subtitle: "Open a blank tab"),

        .init(name: "New Window",
              systemImage: "macwindow.badge.plus",
              action: .newWindow, showsChevron: false,
              subtitle: "Open a blank window"),

        .init(name: "New Private Window",
              systemImage: "eye.slash.fill",
              action: .newPrivateWindow, showsChevron: false,
              subtitle: "Browse without saving history"),

        .init(name: "New Window At…",
              systemImage: "macwindow.badge.plus",
              action: .newWindowAt, showsChevron: true,
              subtitle: "Open a window with a website"),

        .init(name: "New Private Window At…",
              systemImage: "eye.slash.fill",
              action: .newPrivateWindowAt, showsChevron: true,
              subtitle: "Open a private window with a website"),

        .init(name: "New Window With Profile…",
              systemImage: "person.fill",
              action: .newWindowWithProfile, showsChevron: true,
              subtitle: "Choose which profile to use"),

        .init(name: "New Profile…",
              systemImage: "person.crop.circle.badge.plus",
              action: .newProfile, showsChevron: true,
              subtitle: "Set up a separate browsing profile"),
    ]

    @State private var urlString = ""
    @State private var showNewProfile = false
    @State private var hideProfileList = false

    @State private var scope: CommandSection?
    @State private var selectedID: String?
    @State private var expanded: Set<CommandSection> = []
    @State private var draggingSection: CommandSection?

    @AppStorage("paletteShowTabs", store: Config.sharedDefaults) var showTabs: Bool = true
    @AppStorage("paletteShowBookmarks", store: Config.sharedDefaults) var showBookmarks: Bool = true
    @AppStorage("paletteShowSearch", store: Config.sharedDefaults) var showSearch: Bool = true
    @AppStorage("paletteShowCommands", store: Config.sharedDefaults) var showCommands: Bool = true
    @AppStorage("paletteShowHistory", store: Config.sharedDefaults) var showHistory: Bool = true
    
    @ObservedObject var windowManager: WindowManager = .shared

    @Binding var searchQuery: String

    @AppStorage("paletteSectionOrder", store: Config.sharedDefaults)
    private var sectionOrderJSON = "[\"tabs\",\"bookmarks\",\"search\",\"commands\",\"history\"]"

    // MARK: Section order

    private var sectionOrder: [CommandSection] {
        guard let data = sectionOrderJSON.data(using: .utf8),
              let order = try? JSONDecoder().decode([CommandSection].self, from: data) else {
            return CommandSection.allCases
        }
        // Sections added in a later version are appended instead of vanishing.
        return order + CommandSection.allCases.filter { !order.contains($0) }
    }

    private var sectionOrderBinding: Binding<[CommandSection]> {
        Binding(
            get: { sectionOrder },
            set: { newValue in
                if let data = try? JSONEncoder().encode(newValue),
                   let json = String(data: data, encoding: .utf8) {
                    self.sectionOrderJSON = json
                }
            }
        )
    }

    private func isEnabled(_ section: CommandSection) -> Bool {
        switch section {
        case .tabs: showTabs
        case .bookmarks: showBookmarks
        case .search: showSearch
        case .commands: showCommands
        case .history: showHistory
        }
    }

    private func visibility(for section: CommandSection) -> Binding<Bool> {
        switch section {
        case .tabs: $showTabs
        case .bookmarks: $showBookmarks
        case .search: $showSearch
        case .commands: $showCommands
        case .history: $showHistory
        }
    }

    // MARK: Results

    /// Every word typed must appear in at least one of the fields.
    private func matches(_ fields: [String]) -> Bool {
        let terms = searchText.split(whereSeparator: \.isWhitespace)
        guard !terms.isEmpty else { return true }
        return terms.allSatisfy { term in
            fields.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    /// Takes matches until `cap`, and reports whether there were more.
    private func take<T>(_ source: [T], cap: Int, where isMatch: (T) -> Bool) -> (items: [T], hasMore: Bool) {
        var result: [T] = []
        for element in source where isMatch(element) {
            if result.count == cap { return (result, true) }
            result.append(element)
        }
        return (result, false)
    }

    private func cap(for section: CommandSection) -> Int {
        if scope == section || expanded.contains(section) {
            return section == .history ? 100 : .max
        }
        return searchText.isEmpty ? 5 : 8
    }

    private var groups: [ResultGroup] {
        guard showData else { return [] }
        return sectionOrder.compactMap(buildGroup)
    }

    private var selectableItems: [PaletteItem] {
        groups.flatMap(\.items)
    }

    private func buildGroup(for section: CommandSection) -> ResultGroup? {
        guard isEnabled(section), scope == nil || scope == section else { return nil }

        switch section {
        case .tabs:
            let tabs = WindowManager.shared.windows.filter {
                matches([$0.title, $0.url?.absoluteString ?? ""])
            }
            // With one tab open and nothing typed, the list would only repeat the current page.
            if scope == nil && searchText.isEmpty && tabs.count <= 1 { return nil }
            guard !tabs.isEmpty else { return nil }

            return ResultGroup(section: .tabs, items: tabs.map { state in
                PaletteItem(
                    id: "tab-\(state.tabID)",
                    title: state.title.isEmpty ? "Untitled Tab" : state.title,
                    subtitle: state.url?.host,
                    symbol: "macwindow",
                    host: state.url?.host,
                    kind: .tab(state)
                )
            })

        case .bookmarks:
            let found = take(bookmarkStore.items, cap: cap(for: .bookmarks)) {
                matches([$0.title, $0.url])
            }
            guard !found.items.isEmpty else { return nil }

            return ResultGroup(
                section: .bookmarks,
                items: found.items.map { mark in
                    let host = URL(string: mark.url)?.host
                    return PaletteItem(
                        id: "bookmark-\(mark.id)",
                        title: mark.title.isEmpty ? (host ?? mark.url) : mark.title,
                        subtitle: host,
                        symbol: "bookmark",
                        host: host,
                        kind: .bookmark(mark)
                    )
                },
                canToggle: found.hasMore || expanded.contains(.bookmarks)
            )

        case .search:
            guard !searchText.isEmpty else { return nil }
            return ResultGroup(section: .search, items: [])

        case .commands:
            let found = commands.filter { matches([$0.name, $0.subtitle ?? ""]) }
            guard !found.isEmpty else { return nil }

            return ResultGroup(section: .commands, items: found.map { command in
                PaletteItem(
                    id: "command-\(command.name)",
                    title: command.name,
                    subtitle: command.subtitle,
                    symbol: command.systemImage,
                    host: nil,
                    kind: .command(command),
                    showsChevron: command.showsChevron,
                    isPrivate: command.isPrivate
                )
            })

        case .history:
            let found = take(historyItems, cap: cap(for: .history)) {
                matches([$0.title, $0.url])
            }
            guard !found.items.isEmpty else { return nil }

            return ResultGroup(
                section: .history,
                items: found.items.map { entry in
                    let host = URL(string: entry.url)?.host
                    return PaletteItem(
                        id: "history-\(entry.id)",
                        title: entry.title.isEmpty ? (host ?? entry.url) : entry.title,
                        subtitle: host,
                        symbol: "clock.arrow.circlepath",
                        host: host,
                        kind: .history(entry)
                    )
                },
                canToggle: found.hasMore || expanded.contains(.history)
            )
        }
    }

    // MARK: Body

    var body: some View {
        Group {
            if showData {
                switch screen {
                case .commands: paletteScreen
                case .profiles: profilesScreen
                case .enterURL(let privateMode): enterURLScreen(privateMode: privateMode)
                }
            } else {
                arrangeScreen
            }
        }
        .frame(minWidth: 420, minHeight: 350)
        .animation(.snappy(duration: 0.2), value: screen)
        .onChange(of: showNewProfile) { _, isShowing in
            // Finished creating a profile from the "New Profile…" command: return to the palette.
            if !isShowing && hideProfileList {
                hideProfileList = false
                transition(to: .commands)
            }
        }
    }

    // MARK: Search bar

    private func searchBar(prompt: String, proxy: ScrollViewProxy?) -> some View {
        HStack(spacing: 10) {
            if screen != .commands {
                Button {
                    searchText = ""
                    showNewProfile = false
                    transition(to: .commands)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(prompt, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($focus, equals: .search)
                    .onSubmit {
                        if screen == .commands { activateSelected() }
                    }
                    .onKeyPress(.downArrow) {
                        guard let proxy else { return .ignored }
                        moveSelection(by: 1, proxy: proxy)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        guard let proxy else { return .ignored }
                        moveSelection(by: -1, proxy: proxy)
                        return .handled
                    }
                    .onKeyPress(.escape) { handleEscape() }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: Palette screen

    private var paletteScreen: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 8) {
                searchBar(prompt: "Search or run a command", proxy: proxy)
                scopeChips
                results(groups: groups, proxy: proxy)
            }
        }
        .onAppear {
            focus = .search
            selectedID = selectableItems.first?.id
        }
        .onChange(of: searchText) { _, _ in
            selectedID = selectableItems.first?.id
        }
        .onChange(of: scope) { _, _ in
            selectedID = selectableItems.first?.id
        }
        .onChange(of: selectableItems.map(\.id)) { _, ids in
            if let selectedID, ids.contains(selectedID) { return }
            selectedID = ids.first
        }
    }

    @ViewBuilder
    private var scopeChips: some View {
        let scopes = sectionOrder.filter { isEnabled($0) && $0 != .search }
        if scopes.count > 1 {
            HStack(spacing: 6) {
                chip("All", value: nil)
                ForEach(scopes) { chip($0.title, value: $0) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
        }
    }

    private func chip(_ title: String, value: CommandSection?) -> some View {
        let isSelected = scope == value
        return Button {
            scope = value
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func results(groups: [ResultGroup], proxy: ScrollViewProxy) -> some View {
        if groups.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(groups) { group in
                        PaletteSectionHeader(
                            section: group.section,
                            count: group.items.count,
                            canToggle: group.canToggle,
                            isExpanded: expanded.contains(group.section),
                            onToggle: { toggleExpanded(group.section) },
                            order: sectionOrderBinding,
                            dragging: $draggingSection
                        )

                        if group.section == .search {
                            AutocompleteView(
                                searchTerm: $searchText,
                                noContentAvView: true,
                                updateOther: Binding<String?>(
                                    get: { searchQuery },
                                    set: { searchQuery = $0 ?? "" }
                                ),
                                loadQuery: {}
                            )
                            .padding(.horizontal, 10)
                        } else {
                            ForEach(group.items) { item in
                                PaletteRow(
                                    item: item,
                                    isSelected: item.id == selectedID,
                                    term: searchText,
                                    onHover: { selectedID = item.id },
                                    onActivate: { activate(item) },
                                    onClose: closeAction(for: item)
                                )
                                .id(item.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func toggleExpanded(_ section: CommandSection) {
        withAnimation(.snappy(duration: 0.2)) {
            if expanded.contains(section) {
                expanded.remove(section)
            } else {
                expanded.insert(section)
            }
        }
    }

    // MARK: Profiles screen

    private var profilesScreen: some View {
        VStack(spacing: 8) {
            searchBar(prompt: "Search profiles", proxy: nil)

            List {
                ProfileView(
                    searchText: $searchText,
                    hideProfileList: $hideProfileList,
                    showNewProfile: $showNewProfile,
                    showHeader: false
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if !showNewProfile && !hideProfileList {
                HStack {
                    Spacer()
                    Button {
                        showNewProfile = true
                    } label: {
                        Label("New Profile", systemImage: "plus")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding([.horizontal, .bottom], 12)
            }
        }
        .onAppear { focus = .search }
    }

    // MARK: Open-at-address screen

    /// Adds https:// when the person types just a domain.
    private var normalizedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate), url.host?.isEmpty == false else { return nil }
        return url
    }

    private func enterURLScreen(privateMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Button {
                    urlString = ""
                    transition(to: .commands)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Text(privateMode ? "Open a private window" : "Open a new window")
                    .font(.headline)
            }

            HStack(spacing: 10) {
                Image(systemName: privateMode ? "eye.slash.fill" : "globe")
                    .foregroundStyle(privateMode ? Color.purple : Color.secondary)

                TextField("Website address", text: $urlString)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($focus, equals: .url)
                    .onSubmit { openURL(privateMode: privateMode) }
                    .onKeyPress(.escape) { handleEscape() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let url = normalizedURL {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Open") {
                    openURL(privateMode: privateMode)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(normalizedURL == nil)
            }
        }
        .padding(12)
        .onAppear { focus = .url }
    }

    private func openURL(privateMode: Bool) {
        guard let url = normalizedURL else { return }
        createNewWindow(with: url, pvt: privateMode)
        dismissAfterFocusResigns()
    }

    // MARK: Arrange screen (settings)

    private var arrangeScreen: some View {
        List {
            Section {
                ForEach(sectionOrder) { section in
                    HStack(spacing: 12) {
                        PaletteIconTile(symbol: section.symbol, tint: .secondary)
                        Text(section.title)
                        Spacer()
                        Toggle("Show \(section.title)", isOn: visibility(for: section))
                            .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }
                .onMove { source, destination in
                    var order = sectionOrder
                    order.move(fromOffsets: source, toOffset: destination)
                    sectionOrderBinding.wrappedValue = order
                }
            } header: {
                Text("Drag to reorder. Turn off sections you don’t need.")
            }
        }
        .listStyle(.inset)
    }

    // MARK: Actions

    private func activateSelected() {
        guard let item = selectableItems.first(where: { $0.id == selectedID }) ?? selectableItems.first else { return }
        activate(item)
    }

    private func activate(_ item: PaletteItem) {
        switch item.kind {
        case .tab(let state):
            switchToTab(tabID: state.tabID)
            dismissAfterFocusResigns()

        case .bookmark(let mark):
            createNewTab(with: URL(string: mark.url))
            dismissAfterFocusResigns()

        case .history(let entry):
            guard let url = URL(string: entry.url) else { return }
            createNewTab(with: url)
            dismissAfterFocusResigns()

        case .command(let command):
            perform(command.action)
        }
    }

    private func closeAction(for item: PaletteItem) -> (() -> Void)? {
        guard case .tab(let state) = item.kind else { return nil }
        return {
            withAnimation(.snappy) {
                windowManager.closeTab(state.tabID)
            }
        }
    }

    private func moveSelection(by delta: Int, proxy: ScrollViewProxy) {
        let items = selectableItems
        guard !items.isEmpty else { return }

        let current = items.firstIndex { $0.id == selectedID }
        let next: Int
        if let current {
            next = (current + delta + items.count) % items.count
        } else {
            next = delta > 0 ? 0 : items.count - 1
        }

        selectedID = items[next].id
        withAnimation(.snappy(duration: 0.15)) {
            proxy.scrollTo(items[next].id)
        }
    }

    private func handleEscape() -> KeyPress.Result {
        switch screen {
        case .commands:
            if !searchText.isEmpty {
                searchText = ""
                return .handled
            }
            if scope != nil {
                scope = nil
                return .handled
            }
            return .ignored

        case .profiles:
            searchText = ""
            showNewProfile = false
            transition(to: .commands)
            return .handled

        case .enterURL:
            urlString = ""
            transition(to: .commands)
            return .handled
        }
    }

    private func perform(_ action: Command.Action) {
        switch action {
        case .newTab:
            createNewTab()
            dismissAfterFocusResigns()

        case .newWindow:
            createNewWindow()
            dismissAfterFocusResigns()

        case .newPrivateWindow:
            createNewWindow(pvt: true)
            dismissAfterFocusResigns()

        case .newWindowAt:
            searchText = ""
            transition(to: .enterURL(privateMode: false))

        case .newPrivateWindowAt:
            searchText = ""
            transition(to: .enterURL(privateMode: true))

        case .newWindowWithProfile:
            searchText = ""
            showNewProfile = false
            hideProfileList = false
            transition(to: .profiles)

        case .newProfile:
            showNewProfile = true
            hideProfileList = true
            transition(to: .profiles)
        }
    }

    private func dismissAfterFocusResigns() {
        PlatformApplication.dismissKeyboard()
        Task { @MainActor in
            await Task.yield()
            dismiss()
        }
    }

    private func transition(to newScreen: Screen) {
        PlatformApplication.dismissKeyboard()
        Task { @MainActor in
            await Task.yield()
            screen = newScreen
            await Task.yield()
            if case .enterURL = newScreen {
                focus = .url
            } else {
                focus = .search
            }
        }
    }
}

// MARK: - Profile list

private struct ProfileRow: View {
    let profile: Profile
    let isSettings: Bool
    let onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            PaletteIconTile(symbol: profile.icon.isEmpty ? "person.fill" : profile.icon)

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                if profile.isEphemeral {
                    Text("Ephemeral")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSettings {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if isHovering {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit profile")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

struct ProfileView: View {

    @AppStorage("profiles", store: Config.sharedDefaults)
    private var profilesJSON = "[]"

    @Environment(\.dismiss) var dismiss

    var isSettings = false

    private var profiles: [Profile] {
        (try? JSONDecoder().decode([Profile].self,
                                   from: Data(profilesJSON.utf8))) ?? []
    }

    @Binding var searchText: String

    @Binding var hideProfileList: Bool
    @Binding var showNewProfile: Bool

    var showHeader = true

    @State private var selectedProfile: Profile?
    @State private var profilePendingDelete: Profile?

    var filteredProfiles: [Profile] {
        let terms = searchText.split(whereSeparator: \.isWhitespace)
        guard !terms.isEmpty else { return profiles }

        return profiles.filter { profile in
            terms.allSatisfy { profile.name.localizedCaseInsensitiveContains($0) }
        }
    }

    var body: some View {
        Section {
            if !hideProfileList {
                if !filteredProfiles.isEmpty {
                    ForEach(filteredProfiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isSettings: isSettings,
                            onEdit: { selectedProfile = profile }
                        )
                        .onTapGesture {
                            if isSettings {
                                selectedProfile = profile
                            } else {
                                createNewWindow(
                                    profile: profile.id.uuidString,
                                    profileIcon: profile.icon.isEmpty ? "person.fill" : profile.icon
                                )
                                dismiss()
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                        .contextMenu {
                            Button {
                                selectedProfile = profile
                            } label: {
                                Label("Edit Profile…", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                profilePendingDelete = profile
                            } label: {
                                Label("Delete Profile…", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    emptyState
                }
            }
        } header: {
            if showHeader {
                Text("Profile")
            }
        }
        .sheet(item: $selectedProfile) { profile in
            ProfileSettingsView(profile: profile)
        }
        .sheet(isPresented: $showNewProfile) {
            NewProfileView()
        }
        .confirmationDialog(
            "Delete “\(profilePendingDelete?.name ?? "")”?",
            isPresented: Binding(
                get: { profilePendingDelete != nil },
                set: { if !$0 { profilePendingDelete = nil } }
            ),
            presenting: profilePendingDelete
        ) { profile in
            Button("Delete Profile", role: .destructive) {
                deleteProfile(profile)
            }
        } message: { _ in
            Text("This removes the profile and all of its browsing data. You can’t undo this.")
        }
        .onAppear {
            let validIDs = Set(profiles.map { $0.id })
            ProfileDataStoreCleanup.removeOrphans(validProfileIDs: validIDs)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if searchText.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No profiles yet")
                    .font(.headline)
                Text("Profiles keep cookies, bookmarks and history separate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            Text("No profiles match “\(searchText)”")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        }
    }

    private func deleteProfile(_ profile: Profile) {
        var current = (try? JSONDecoder().decode(
            [Profile].self,
            from: Data(profilesJSON.utf8)
        )) ?? []

        current.removeAll { $0.id == profile.id }

        guard let data = try? JSONEncoder().encode(current),
              let encoded = String(data: data, encoding: .utf8) else { return }
        profilesJSON = encoded

        ProfileDataStoreCleanup.remove(profile: profile, remainingProfiles: current)
    }
}

// MARK: - Profile data cleanup (unchanged)

enum ProfileDataStoreCleanup {
    /// Completely removes a profile's WebKit website data store, on-disk directories, and associated defaults.
    static func remove(profile: Profile, remainingProfiles: [Profile]) {
        let profileID = profile.id
        let uuidString = profileID.uuidString

        // 1. Reset defaultProfile if it matches
        let defaults = Config.sharedDefaults ?? UserDefaults.standard
        if defaults.string(forKey: "defaultProfile") == uuidString {
            defaults.set("", forKey: "defaultProfile")
        }

        // 2. Remove profile-scoped UserDefaults keys
        let keysToRemove = [
            "bookmarks_\(uuidString)",
            "sidebar_\(uuidString)",
            "downloads_\(uuidString)",
            "pins_\(uuidString)",
            "toolbar_\(uuidString)",
            "chat_threads_\(uuidString)",
            "chat_active_thread_\(uuidString)",
            "tabs_\(uuidString)",
            "user_agent_\(uuidString)",
            "homepage_\(uuidString)",
            "ad_block_\(uuidString)"
        ]
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
            Config.defaults.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 3. WebKit Data Store removal API
        if #available(macOS 14.0, *) {
            WKWebsiteDataStore.remove(forIdentifier: profileID) { error in
                if let error = error {
                    print("Failed to remove profile data store: \(error)")
                } else {
                    print("Profile data wiped completely")
                }
            }
        } else {
            let store = WKWebsiteDataStore(forIdentifier: profileID)
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            store.fetchDataRecords(ofTypes: types) { records in
                store.removeData(ofTypes: types, for: records) {
                    print("Profile data cleared")
                }
            }
        }

        // 4. Remove disk directory from Library/WebKit/WebsiteDataStore/<uuid>
        removeDiskDataStore(for: profileID)

        // 5. Sweep any orphaned WebsiteDataStore directories
        let validIDs = Set(remainingProfiles.map { $0.id })
        removeOrphans(validProfileIDs: validIDs)
    }

    /// Removes disk directory for a specific profile UUID
    static func removeDiskDataStore(for profileID: UUID) {
        guard let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let baseDir = libraryURL.appendingPathComponent("WebKit/WebsiteDataStore", isDirectory: true)
        let uuidString = profileID.uuidString

        let pathsToCheck = [
            baseDir.appendingPathComponent(uuidString),
            baseDir.appendingPathComponent(uuidString.lowercased()),
            baseDir.appendingPathComponent(uuidString.uppercased())
        ]

        for path in pathsToCheck {
            if FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
            }
        }

        // Also check any directory whose name matches case-insensitively
        if let subdirs = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) {
            for subdir in subdirs where subdir.lastPathComponent.caseInsensitiveCompare(uuidString) == .orderedSame {
                try? FileManager.default.removeItem(at: subdir)
            }
        }
    }

    /// Removes disk directories and WebKit stores for UUIDs not in validProfileIDs
    static func removeOrphans(validProfileIDs: Set<UUID>) {
        guard let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let baseDir = libraryURL.appendingPathComponent("WebKit/WebsiteDataStore", isDirectory: true)
        guard FileManager.default.fileExists(atPath: baseDir.path),
              let subdirs = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) else { return }

        for subdir in subdirs {
            let name = subdir.lastPathComponent
            if let dirUUID = UUID(uuidString: name) {
                if !validProfileIDs.contains(dirUUID) {
                    try? FileManager.default.removeItem(at: subdir)
                    if #available(macOS 14.0, *) {
                        WKWebsiteDataStore.remove(forIdentifier: dirUUID) { _ in }
                    }
                }
            }
        }
    }
}

// MARK: - New / edit profile

struct NewProfileView: View {
    let profileID: UUID?

    @AppStorage("profiles", store: Config.sharedDefaults)
    private var profilesJSON = "[]"

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    @State private var nameInput = ""
    @State private var iconInput = "person.crop.circle"
    @State private var imapHostInput = ""
    @State private var imapPortInput = "993"
    @State private var imapEmailInput = ""
    @State private var imapPasswordInput = ""
    @State private var showCustomIcon = false
    @State private var showIMAP = false
    @State private var isEphemeral = false
    @State private var didLoadProfile = false

    init(profileID: UUID? = nil) {
        self.profileID = profileID
    }

    private static let iconChoices: [(name: String, symbol: String)] = [
        ("Person", "person.crop.circle"),
        ("Briefcase", "briefcase.fill"),
        ("Graduation Cap", "graduationcap.fill"),
        ("Book", "book.fill"),
        ("Globe", "globe"),
        ("Star", "star.fill"),
        ("Heart", "heart.fill"),
        ("Gamepad", "gamecontroller.fill"),
        ("Terminal", "terminal.fill")
    ]

    private var isEditing: Bool { profileID != nil }

    private var effectiveIcon: String {
        iconInput.isEmpty ? "person.crop.circle" : iconInput
    }

    private var portIsValid: Bool {
        imapPortInput.isEmpty || UInt16(imapPortInput) != nil
    }

    private var canSave: Bool {
        !nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && portIsValid
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack(spacing: 14) {
                        PaletteIconTile(symbol: effectiveIcon, size: 44)

                        TextField("Profile name", text: $nameInput)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .focused($nameFocused)
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 8)], spacing: 8) {
                        ForEach(Self.iconChoices, id: \.symbol) { choice in
                            iconButton(name: choice.name, symbol: choice.symbol)
                        }
                    }

                    DisclosureGroup("Use a different symbol", isExpanded: $showCustomIcon) {
                        TextField("SF Symbol name", text: $iconInput)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section {
                    Toggle(isOn: $isEphemeral) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ephemeral profile")
                            Text("Keeps your settings but doesn’t save browsing data. Good for temporary sessions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    DisclosureGroup("Email settings (optional)", isExpanded: $showIMAP) {
                        TextField("IMAP host (e.g. imap.gmail.com)", text: $imapHostInput)
                        TextField("IMAP port (e.g. 993)", text: $imapPortInput)
                        if !portIsValid {
                            Text("Enter a port number between 0 and 65535.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        TextField("Email address", text: $imapEmailInput)
                        SecureField("Password", text: $imapPasswordInput)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save Changes" : "Create Profile") {
                    saveProfile()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .controlSize(.large)
            .padding()
        }
        .frame(minWidth: 420, idealWidth: 460)
        .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
        .onAppear {
            loadProfile()
            if !isEditing { nameFocused = true }
        }
    }

    private func iconButton(name: String, symbol: String) -> some View {
        let isSelected = effectiveIcon == symbol
        return Button {
            iconInput = symbol
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(width: 40, height: 40)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func loadProfile() {
        guard !didLoadProfile else { return }
        didLoadProfile = true
        guard let profileID,
              let profile = decodedProfiles.first(where: { $0.id == profileID }) else { return }

        nameInput = profile.name
        iconInput = profile.icon
        imapHostInput = profile.imapHost ?? ""
        imapPortInput = profile.imapPort.map(String.init) ?? "993"
        isEphemeral = profile.isEphemeral
        showCustomIcon = !profile.icon.isEmpty && !Self.iconChoices.contains { $0.symbol == profile.icon }

        let domain = credentialDomain(for: profile.id)
        if let credential = PasswordManager.shared.fetchCredentialDirectly(for: domain) {
            imapEmailInput = credential.username
            imapPasswordInput = credential.passwordString
        }
        showIMAP = profile.imapHost != nil || !imapEmailInput.isEmpty
    }

    private var decodedProfiles: [Profile] {
        (try? JSONDecoder().decode([Profile].self, from: Data(profilesJSON.utf8))) ?? []
    }

    private func saveProfile() {
        let name = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        var profiles = decodedProfiles
        let id = profileID ?? UUID()
        let profile = Profile(
            id: id,
            name: name,
            icon: effectiveIcon,
            isEphemeral: isEphemeral,
            imapHost: imapHostInput.isEmpty ? nil : imapHostInput,
            imapPort: UInt16(imapPortInput)
        )

        if let index = profiles.firstIndex(where: { $0.id == id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }

        guard let data = try? JSONEncoder().encode(profiles),
              let encoded = String(data: data, encoding: .utf8) else { return }
        profilesJSON = encoded

        let domain = credentialDomain(for: id)
        if let oldCredential = PasswordManager.shared.fetchCredentialDirectly(for: domain),
           oldCredential.username != imapEmailInput,
           !imapEmailInput.isEmpty {
            PasswordManager.shared.updateUsername(
                oldUsername: oldCredential.username,
                newUsername: imapEmailInput,
                domain: domain
            )
        }
        if !imapEmailInput.isEmpty && !imapPasswordInput.isEmpty {
            PasswordManager.shared.savePassword(
                username: imapEmailInput,
                passwordString: imapPasswordInput,
                domain: domain
            )
        }

        dismiss()
    }

    private func credentialDomain(for id: UUID) -> String {
        "balance.profile.imap.\(id.uuidString)"
    }
}

// MARK: - Profile settings

struct ProfileSettingsView: View {

    var profile: Profile

    @Environment(\.dismiss) var dismiss

    private enum Pane: String, CaseIterable, Identifiable {
        case profile = "Profile"
        case data = "Data"
        var id: String { rawValue }
    }

    @State private var pane: Pane = .profile

    var body: some View {
        VStack(spacing: 12) {
            Picker("Section", selection: $pane) {
                ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.top)

            switch pane {
            case .profile:
                NewProfileView(profileID: profile.id)
            case .data:
                WebDataView(profile: profile.id.uuidString)
                    .padding(.horizontal)

                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding([.horizontal, .bottom])
            }
        }
        .frame(minWidth: 460, minHeight: 440)
    }
}
