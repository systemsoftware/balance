import SwiftUI
internal import UniformTypeIdentifiers

enum ToolbarItemType: String, Codable, CaseIterable, Identifiable {
    case clock
    case navigation
    case home
    case share
    case reload
    case addressBar
    case search
    case autocomplete
    case autofill
    case extensions
    case saveTo
    case splitView
    case commandPalette
    case findInPage
    case spacer
    case ai
    case restyle
    case more
    case reader
    case mute
    case duplicate
    case zoom
    case rename
    
    var name: String {
        
        switch self {
        case .clock:
            "Clock"
        case .navigation:
            "Navigation"
        case .home:
            "Home"
        case .share:
            "Share"
        case .reload:
            "Reload"
        case .addressBar:
            "Address Bar"
        case .search:
            "Go"
        case .autocomplete:
            "Autocomplete"
        case .autofill:
            "Autofill"
        case .extensions:
            "Extensions"
        case .saveTo:
            "Save To"
        case .splitView:
            "Split View"
        case .commandPalette:
            "Command Palette"
        case .findInPage:
            "Find in Page"
        case .more:
            "More Menu"
        case .ai:
            "AI Tools"
        case .restyle:
            "Restyle Page"
        default:
            self.rawValue.capitalized
        }
        
    }

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .clock: "clock"
        case .navigation: "chevron.left.chevron.right"
        case .home: "house"
        case .share: "square.and.arrow.up"
        case .reload: "arrow.clockwise"
        case .addressBar: "link"
        case .search: "arrow.turn.down.right"
        case .autocomplete: "character.cursor.ibeam"
        case .autofill: "rectangle.and.pencil.and.ellipsis"
        case .extensions: "puzzlepiece.extension"
        case .saveTo: "star"
        case .splitView: "rectangle.split.2x1"
        case .commandPalette: "text.and.command.macwindow"
        case .findInPage: "doc.text.magnifyingglass"
        case .spacer: "space"
        case .ai: "sparkles"
        case .restyle: "paintpalette"
        case .more: "ellipsis"
        case .reader: "eyeglasses"
        case .mute: "speaker"
        case .duplicate: "plus.square.on.square"
        case .zoom: "plus.magnifyingglass"
        case .rename: "pencil"
        }
    }
}

enum ToolbarSheet: String, Identifiable {
    case commands
    case tabSearch
    case events
    case goTo
    case restyle
    case splitURL
    case rename
    case summary

    var id: String { rawValue }
}

struct ToolbarItemLabel: View {
    let expanded: Bool
    let title: String
    let systemImage: String

    var body: some View {
        if expanded {
            Label(title, systemImage: systemImage)
        } else {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
        }
    }
}

struct BrowserToolbar: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @ObservedObject var browserState: BrowserState
    @ObservedObject var sidebarStore: SidebarStore
    @ObservedObject var bookmarkStore: BookmarkStore
    @StateObject var toolbarStore = ToolbarStore()
    @Binding var location: URL?
    @Binding var urlInput: String
    @Binding var showTrustInfo: Bool
    @Binding var activeSheet: ToolbarSheet?
    @Binding var summarizing: Bool
    @Binding var splitURL: String
    @ObservedObject var splitState: BrowserState
    let focusAddressOnAppear: Bool
    let isPrivate: Bool
    let profileIcon: String?
    let profileName: String?
    let submitURL: () -> Void
    let scanEvents: () async -> Void
    @Binding var showReader: Bool
    
    @State private var showAddRemoveMenu = false
    
    @State private var draggedItemID: UUID?
    
    @State var showEdit = false
    @State var editSection = 0

    @AppStorage("showToolbarDragHandle") private var showDrag = false
    @AppStorage("toolbarLocation") private var toolbarLocation = 0

    private var hasCompactHeight: Bool { verticalSizeClass == .compact }
    
    var body: some View {
        
        HStack {
            if !toolbarStore.items.isEmpty {
                ForEach(toolbarStore.items) { entry in
                    
                    BrowserToolbarItem(
                        item: entry.item,
                        inactiveItems: inactiveToolbarItems,
                        browserState: browserState,
                        sidebarStore: sidebarStore,
                        bookmarkStore: bookmarkStore,
                        location: $location,
                        urlInput: $urlInput,
                        showTrustInfo: $showTrustInfo,
                        activeSheet: $activeSheet,
                        summarizing: $summarizing,
                        splitURL: $splitURL,
                        splitState: splitState,
                        focusAddressOnAppear: focusAddressOnAppear,
                        isPrivate: isPrivate,
                        profileIcon: profileIcon,
                        profileName: profileName,
                        showReader: $showReader,
                        submitURL: submitURL,
                        scanEvents: scanEvents
                    )
                    
                    .padding(Layout.controlPadding)
                    .modifier(ToolbarDragSource(entry: entry, draggedItemID: $draggedItemID))
                    .onDrop(
                        of: [.plainText],
                        delegate: ToolbarDropDelegate(
                            targetID: entry.id,
                            store: toolbarStore,
                            draggedItemID: $draggedItemID
                        )
                    )
                    .contextMenu {
                        Button {
                            showEdit = true
                        } label: {
                            Text("Customize Toolbar")
                        }
                    }
                    
                    
                }
            } else {
                EmptyView()
                    .contextMenu {
                        
                    }
            }

            if browserState.isFindBarVisible && !toolbarStore.contains(.findInPage) {
                FindBarView(state: browserState)
                    .padding(Layout.controlPadding)
            }
        }
        .padding(.top, 5)
        
   /*     .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .allowsHitTesting(false)
                .padding(.horizontal, 5)
        }
    */
        .popover(
            isPresented: $showEdit,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: toolbarLocation == 0 ? .top : .bottom
        ) {
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    Text("Customize Toolbar")
                        .font(.headline)
                    
                    Picker("", selection: $editSection.animation(.bouncy)) {
                        Text("Add").tag(0)
                        Text("Remove").tag(1)
                        Text("Options").tag(2)
                    }
                    .pickerStyle(.segmented)
                    
                    //          ScrollView {
                    switch editSection {
                    case 0:
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(ToolbarItemType.allCases) { newItem in
                                if newItem == .spacer || !toolbarStore.contains(newItem) {
                                    Button {
                                        withAnimation(.bouncy) {
                                            toolbarStore.add(newItem)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: newItem.systemImage)
                                                .foregroundStyle(.secondary)
                                            Text(newItem.name)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(Color.primary.opacity(0.001))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                    case 1:
                        if toolbarStore.items.isEmpty {
                            Text("No items to remove")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(toolbarStore.items) { removeEntry in
                                    Button {
                                        withAnimation(.bouncy) {
                                            toolbarStore.remove(id: removeEntry.id)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: removeEntry.item.systemImage)
                                                .foregroundStyle(.red)
                                            Text(removeEntry.item.name)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(Color.primary.opacity(0.001))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        
                    default:
                        Toggle(isOn: $showDrag) {
                            Text("Show Address Bar Drag Handle")
                        }
                        .padding(.vertical, 4)
                    }
                    //      }
                    //          .animation(.bouncy, value: editSection)
                    Text("Drag toolbar items to reorder them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.visible)
            .fittedMenuPopover(
                minHeight: hasCompactHeight ? 240 : 420,
                idealHeight: hasCompactHeight ? 320 : 520,
                maxHeight: hasCompactHeight ? 360 : 580
            )
        }
    }

    private var inactiveToolbarItems: [ToolbarItemType] {
        let activeItems = Set(toolbarStore.items.map(\.item))
        return ToolbarItemType.allCases.filter {
            $0 != .clock && !activeItems.contains($0)
        }
    }
    
    struct BrowserToolbarItem: View {
        
        var item: ToolbarItemType
        var inactiveItems: [ToolbarItemType]
        var expandedLabel = false
        
        @ObservedObject var browserState: BrowserState
        @ObservedObject var sidebarStore: SidebarStore
        @ObservedObject var bookmarkStore: BookmarkStore
        
        @Binding var location: URL?
        @Binding var urlInput: String
        @Binding var showTrustInfo: Bool
        @Binding var activeSheet: ToolbarSheet?
        @Binding var summarizing: Bool
        @Binding var splitURL: String
        @ObservedObject var splitState: BrowserState
        let focusAddressOnAppear: Bool
        let isPrivate: Bool
        let profileIcon: String?
        let profileName: String?
        @Binding var showReader: Bool
        
        let submitURL: () -> Void
        let scanEvents: () async -> Void
        
        @State var t = ""
        
        @State var showSuggestions = false
        @AppStorage("toolbarLocation") private var toolbarLocation = 0
        @AppStorage(AutofillPreferences.enabledKey, store: Config.sharedDefaults)
        private var autofillEnabled = true
        
        @ViewBuilder private var toolbarContent: some View {
            HStack {
                switch item {
                case .clock:
                    ClockView(timeOnly: true, fontSize: 14)
                    
                case .navigation:
                    NavigationButtons(location: $location, browserState: browserState, expandedLabel: expandedLabel)
                    
                case .home:
                    HomeToolbarButton(location: $location, urlInput: $urlInput, expandedLabel: expandedLabel)
                    
                case .share:
                    ShareToolbarButton(location: $location, expandedLabel: expandedLabel)
                    
                case .reload:
                    ReloadToolbarButton(browserState: browserState, expandedLabel: expandedLabel)
                    
                case .addressBar:
                    AddressBar(
                        browserState: browserState,
                        location: $location,
                        urlInput: $urlInput,
                        showTrustInfo: $showTrustInfo,
                        focusOnAppear: focusAddressOnAppear,
                        isPrivate: isPrivate,
                        profileIcon: profileIcon,
                        profileName: profileName,
                        submitURL: submitURL
                    )
                    
                case .search:
                    SearchToolbarButton(location: $location, expandedLabel: expandedLabel, submitURL: submitURL)
                    
                case .autocomplete:
                    Button {
                        guard !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            showSuggestions = false
                            return
                        }
                        showSuggestions.toggle()
                    } label: {
                        Image(systemName: "character.cursor.ibeam")
                            .font(.title2)
                            .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
                    }
                    .frame(width: 40, height: 40)
                    .buttonStyle(.plain)
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .onChange(of: urlInput) { _, newValue in
                        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            showSuggestions = false
                        }
                    }
                    .popover(
                        isPresented: $showSuggestions,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: toolbarLocation == 0 ? .top : .bottom
                    ) {
                        AutoFillPopover(searchTerm: $urlInput)
                            .roomyToolbarPopover()
                    }
                    
                case .autofill:
                    Button {
                        autofillEnabled.toggle()
                        if !autofillEnabled {
                            AutofillPopoverManager.shared.hide()
                        }
                    } label: {
                            ToolbarItemLabel(expanded: expandedLabel, title: item.name, systemImage: item.systemImage)
                            .foregroundStyle(autofillEnabled ? Color.primary : Color.secondary)
                    }
                    .frame(width: 40, height: 40)
                    .buttonStyle(.plain)
                    .background(AutofillToolbarPopoverAnchor())
                    .help(autofillEnabled ? "Turn Off Autofill" : "Turn On Autofill")
                    .accessibilityLabel("Autofill")
                    .accessibilityValue(autofillEnabled ? "On" : "Off")
                    .disabled(location == nil)
                    
                case .extensions:
                    ExtensionsToolbarButton(browserState: browserState, location: $location)
                    
                case .saveTo:
                    SaveToToolbarButton(location: $location, sidebarStore: sidebarStore, bookmarkStore: bookmarkStore, expandedLabel: expandedLabel)
                    
                case .splitView:
                    SplitViewToolbarButton(
                        splitURL: $splitURL,
                        splitState: splitState,
                        expandedLabel: expandedLabel,
                        presentURLSheet: { activeSheet = .splitURL }
                    )
                        .disabled(location == nil)
                    
                case .reader:
                    Button {
                        showReader.toggle()
                    } label: {
                        ToolbarItemLabel(expanded: expandedLabel, title: item.name, systemImage: item.systemImage)
                    }
                    .buttonStyle(.plain)
                    .disabled(location == nil)
                    
                case .spacer:
                    Color.clear
                        .frame(
                            minWidth: Layout.toolbarButtonSize,
                            maxWidth: Layout.toolbarButtonSize * 2
                        )
                        .frame(height: Layout.toolbarButtonSize)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Toolbar Spacer")
                    
                case .more:
                    MoreMenuToolbar(items: inactiveItems) { inactiveItem in
                        AnyView(
                            BrowserToolbarItem(
                                item: inactiveItem,
                                inactiveItems: [],
                                expandedLabel: true,
                                browserState: browserState,
                                sidebarStore: sidebarStore,
                                bookmarkStore: bookmarkStore,
                                location: $location,
                                urlInput: $urlInput,
                                showTrustInfo: $showTrustInfo,
                                activeSheet: $activeSheet,
                                summarizing: $summarizing,
                                splitURL: $splitURL,
                                splitState: splitState,
                                focusAddressOnAppear: focusAddressOnAppear,
                                isPrivate: isPrivate,
                                profileIcon: profileIcon,
                                profileName: profileName,
                                showReader: $showReader,
                                submitURL: submitURL,
                                scanEvents: scanEvents
                            )
                        )
                    }
                case .commandPalette:
                    CommandPaletteToolbarButton(expandedLabel: expandedLabel) { activeSheet = .commands }
                    
                case .findInPage:
                    FindInPageToolbarButton(browserState: browserState, expandedLabel: expandedLabel)
                    
                case .ai:
                    AIMenuToolbar(browserState: browserState, location: $location, expandedLabel: expandedLabel, summarizing: $summarizing, presentSummarySheet: { activeSheet = .summary }, scanEvents: scanEvents
                    )
                case .restyle:
                    RestyleToolbarButton(expandedLabel: expandedLabel) { activeSheet = .restyle }
                        .disabled(location == nil)
                case .mute:
                    MuteToolbar(location: $location, browserState: browserState, expandedLabel: expandedLabel)
                case .duplicate:
                    DuplicateToolbarButton(location: $location, expandedLabel: expandedLabel)
                case .rename:
                    RenameToolbar(location: $location, presentRenameSheet:  { activeSheet = .rename }, expandedLabel:expandedLabel)
                case .zoom:
                    ZoomToolbar(location: $location, browserState: browserState, expandedLabel: expandedLabel)
                }
            }
        }

        var body: some View {
            if expandedLabel {
                toolbarContent
            } else {
                toolbarContent.glassEffect(.regular.interactive())
            }
        }
        
        
    }
}

private struct ToolbarDragSource: ViewModifier {
    let entry: ToolbarEntry
    @Binding var draggedItemID: UUID?
    
    @AppStorage("showToolbarDragHandle") private var showDrag = false

    func body(content: Content) -> some View {
        if entry.item == .addressBar && showDrag {
            HStack(spacing: 4) {
                content
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
                    .help("Drag to move the address bar")
                    .accessibilityLabel("Move Address Bar")
                    .onDrag { dragProvider() }
            }
        } else {
            content.onDrag { dragProvider() }
        }
    }

    private func dragProvider() -> NSItemProvider {
        draggedItemID = entry.id
        return NSItemProvider(object: entry.id.uuidString as NSString)
    }
}
