import SwiftUI
import WebKit

// MARK: - Display options

enum TabLayout: String, CaseIterable, Identifiable {
    case grid, list

    var id: String { rawValue }
    var label: String { self == .grid ? "Grid" : "List" }
    var symbol: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

enum TabGrouping: String, CaseIterable, Identifiable {
    case none, site

    var id: String { rawValue }
    var label: String { self == .none ? "No grouping" : "Group by site" }
    var symbol: String { self == .none ? "rectangle.stack" : "globe" }
}

private struct TabSection: Identifiable {
    let title: String?
    let tabs: [BrowserState]
    var id: String { title ?? "all" }
}

struct TabSearchView: View {
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    @AppStorage("tabSwitcher.layout") private var layout: TabLayout = .grid
    @AppStorage("tabSwitcher.grouping") private var grouping: TabGrouping = .none

    var showSearch = true
    var isPopover = false

    var activeTab: BrowserState? = nil

    var store = PinStore()

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var windowManager: WindowManager

    // MARK: Data

    var filteredStates: [BrowserState] {
        let terms = searchText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return windowManager.windows }

        return windowManager.windows.filter { state in
            let address = state.url?.absoluteString ?? ""
            return terms.allSatisfy {
                state.title.localizedCaseInsensitiveContains($0)
                || address.localizedCaseInsensitiveContains($0)
            }
        }
    }

    private var sections: [TabSection] {
        switch grouping {
        case .none:
            return [TabSection(title: nil, tabs: filteredStates)]
        case .site:
            let groups = Dictionary(grouping: filteredStates) { $0.url?.host ?? "Other" }
            return groups.keys.sorted().map { TabSection(title: $0, tabs: groups[$0] ?? []) }
        }
    }

    private var duplicateTabs: [BrowserState] {
        var seen = Set<String>()
        var duplicates: [BrowserState] = []
        for state in windowManager.windows {
            guard let key = state.url?.absoluteString else { continue }
            if !seen.insert(key).inserted { duplicates.append(state) }
        }
        return duplicates
    }

    // MARK: Actions

    private func open(_ state: BrowserState) {
        switchToTab(tabID: state.tabID)
        if isPopover { dismiss() }
    }

    private func close(_ state: BrowserState) {
        withAnimation(.snappy) {
            windowManager.closeTab(state.tabID)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header

            if filteredStates.isEmpty {
                emptyState
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 14) {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            ForEach(sections) { section in
                                sectionView(section)
                            }
                        }
                    }
                    .padding([.horizontal, .bottom])
                    .padding(.top, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: isPopover ? 440 : nil, minHeight: isPopover ? 380 : nil)
        .animation(.snappy(duration: 0.25), value: layout)
        .animation(.snappy(duration: 0.25), value: grouping)
        .animation(.snappy(duration: 0.25), value: filteredStates)
        .onAppear {
            if isPopover && showSearch { searchFocused = true }
        }
        .onKeyPress(.escape) {
            guard !searchText.isEmpty else { return .ignored }
            searchText = ""
            return .handled
        }
        // ⌘F jumps to the search field.
        .background {
            Button("Find Tab") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if showSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search tabs", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($searchFocused)
                            .onSubmit {
                                if let first = filteredStates.first { open(first) }
                            }

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
                } else {
                    Spacer(minLength: 0)
                }

                optionsMenu
            }

            Text(countLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .contentTransition(.numericText())
        }
        .padding()
    }

    private var countLabel: String {
        let total = windowManager.windows.count
        let shown = filteredStates.count
        if searchText.isEmpty {
            return total == 1 ? "1 tab" : "\(total) tabs"
        }
        return "\(shown) of \(total) tabs"
    }

    private var optionsMenu: some View {
        Menu {
            Picker("Layout", selection: $layout) {
                ForEach(TabLayout.allCases) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.inline)

            Picker("Grouping", selection: $grouping) {
                ForEach(TabGrouping.allCases) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.inline)

          
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 38, height: 38)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .accessibilityLabel("Tab view options")
    }

    // MARK: Sections

    @ViewBuilder
    private func sectionView(_ section: TabSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.title {
                HStack(spacing: 8) {
                    Favicon(title)
                    Text(title)
                        .font(.headline)
                    Text("\(section.tabs.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            switch layout {
            case .grid:
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 14)],
                    spacing: 14
                ) {
                    rows(for: section)
                }
            case .list:
                LazyVStack(spacing: 10) {
                    rows(for: section)
                }
            }
        }
    }

    private func rows(for section: TabSection) -> some View {
        ForEach(section.tabs, id: \.self) { state in
            WindowRow(
                browserState: state,
                layout: layout,
                isActive: activeTab === state,
                onSelect: { open(state) },
                onClose: { close(state) }
            )
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    // MARK: Empty state

    @ViewBuilder
    private var emptyState: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "No open tabs",
                systemImage: "square.on.square",
                description: Text("Tabs you open will show up here.")
            )
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}

// MARK: - Tab card / row

struct WindowRow: View {
    @ObservedObject var browserState: BrowserState

    var layout: TabLayout = .grid
    var isActive = false
    var onSelect: () -> Void = {}
    var onClose: (() -> Void)? = nil

    @State private var snapshot: UniversalImage?
    @State private var isHovering = false

    private var displayTitle: String {
        browserState.title.isEmpty ? "Untitled Tab" : browserState.title
    }

    private var host: String { browserState.url?.host ?? "" }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: layout == .grid ? 20 : 16, style: .continuous)
    }

    var body: some View {
        content
            .padding(layout == .grid ? 10 : 8)
            .glassEffect(.regular.interactive(), in: cardShape)
            .overlay {
                if isActive {
                    cardShape.strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) { closeButton }
            .contentShape(cardShape)
            .onTapGesture(perform: onSelect)
            .onHover { isHovering = $0 }
            .contextMenu { menuItems }
            .task(id: browserState.url) {
                if let webView = browserState.webView {
                    webView.takeSnapshot(with: nil) { image, error in
                        if let image = image {
                            snapshot = UniversalImage(data: image.pngData ?? Data()) ?? nil
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(displayTitle)
            .accessibilityHint(host)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Layouts

    @ViewBuilder
    private var content: some View {
        switch layout {
        case .grid:
            VStack(alignment: .leading, spacing: 10) {
                thumbnail
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                caption
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }
        case .list:
            HStack(spacing: 12) {
                thumbnail
                    .frame(width: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                caption
                Spacer(minLength: 0)
            }
            .padding(.trailing, 28) // room for the close button
        }
    }

    /// 16:10 preview. Shows the top of the page; falls back to the favicon
    /// for tabs that have no live web view (e.g. suspended tabs).
    private var thumbnail: some View {
        Color.clear
            .aspectRatio(16 / 10, contentMode: .fit)
            .overlay(alignment: .top) {
                if let snapshot {
                    Image(universalImage: snapshot)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        VStack(spacing: 6) {
                            Favicon(host)
                            if browserState.webView == nil {
                                Text("Not loaded")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .clipped()
    }

    private var caption: some View {
        HStack(spacing: 8) {
            Favicon(host)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if !host.isEmpty {
                    Text(host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Close button

    @ViewBuilder
    private var closeButton: some View {
        if let onClose {
            #if os(macOS)
            let visible = isHovering
            #else
            let visible = true
            #endif

            if visible {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(layout == .grid ? 16 : 10)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .accessibilityLabel("Close \(displayTitle)")
            }
        }
    }

    // MARK: Context menu

    @ViewBuilder
    private var menuItems: some View {
        Button("Open", systemImage: "arrow.up.forward.app", action: onSelect)

        if let url = browserState.url {
            Button("Copy Link", systemImage: "link") { copy(url) }
            ShareLink(item: url) {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        Button("Export to PDF", systemImage: "doc.richtext") {
            browserState.exportWebViewToPDF()
        }
        .disabled(browserState.webView == nil)

        if let onClose {
            Divider()
            Button("Close Tab", systemImage: "xmark", role: .destructive, action: onClose)
        }
    }

    private func copy(_ url: URL) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #else
        UIPasteboard.general.string = url.absoluteString
        #endif
    }

}
