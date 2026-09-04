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
        case .navigation: "chevron.left.forwardslash.chevron.right"
        case .home: "house"
        case .share: "square.and.arrow.up"
        case .reload: "arrow.clockwise"
        case .addressBar: "link"
        case .search: "arrow.turn.down.right"
        case .autocomplete: "character.cursor.ibeam"
        case .extensions: "puzzlepiece.extension"
        case .saveTo: "star"
        case .splitView: "rectangle.split.2x1"
        case .commandPalette: "command"
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

struct BrowserToolbar: View {
    
    @ObservedObject var browserState: BrowserState
    @ObservedObject var sidebarStore: SidebarStore
    @ObservedObject var bookmarkStore: BookmarkStore
    @StateObject var toolbarStore = ToolbarStore()
    @Binding var location: URL?
    @Binding var urlInput: String
    @Binding var showTrustInfo: Bool
    @Binding var showTabSearch: Bool
    @Binding var showEventPopup: Bool
    @Binding var showGoTo: Bool
    @Binding var showBoost: Bool
    @Binding var splitURL: String
    @ObservedObject var splitState: BrowserState
    let focusAddressOnAppear: Bool
    let isPrivate: Bool
    let profileIcon: String?
    let profileName: String?
    let events: [EventExtraction]
    let submitURL: () -> Void
    let scanEvents: () async -> Void
    @Binding var showReader: Bool
    
    @State private var showAddRemoveMenu = false
    
    @State private var draggedItemID: UUID?
    
    @State var showEdit = false
    @State var editSection = 0

    @AppStorage("showToolbarDragHandle") private var showDrag = false

    
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
                        showTabSearch: $showTabSearch,
                        showEventPopup: $showEventPopup,
                        showGoTo: $showGoTo,
                        showBoost: $showBoost,
                        splitURL: $splitURL,
                        splitState: splitState,
                        focusAddressOnAppear: focusAddressOnAppear,
                        isPrivate: isPrivate,
                        profileIcon: profileIcon,
                        profileName: profileName,
                        events: events,
                        showReader: $showReader,
                        submitURL: submitURL,
                        scanEvents: scanEvents
                    )
                    
                    .padding(Layout.controlPadding)
                    .modifier(ToolbarDragSource(entry: entry, draggedItemID: $draggedItemID))
                    .onDrop(
                        of: [.data],
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
        .popover(isPresented: $showEdit) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Customize Toolbar")
                    .font(.headline)
                
                Picker("", selection: $editSection) {
                    Text("Add").tag(0)
                    Text("Remove").tag(1)
                    Text("Options").tag(2)
                }
                .pickerStyle(.segmented)
                
                ScrollView {
                    switch editSection {
                    case 0:
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(ToolbarItemType.allCases) { newItem in
                                if newItem == .spacer || !toolbarStore.contains(newItem) {
                                    Button {
                                        toolbarStore.add(newItem)
                                    } label: {
                                        HStack {
                                            Text(newItem.name)
                                            Spacer()
                                            Image(systemName: "plus.circle")
                                                .foregroundStyle(.secondary)
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
                                        toolbarStore.remove(id: removeEntry.id)
                                    } label: {
                                        HStack {
                                            Text(removeEntry.item.name)
                                            Spacer()
                                            Image(systemName: "minus.circle")
                                                .foregroundStyle(.red)
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
                }
       //         .frame(width: 280)
                .frame(maxHeight: 400)
                .animation(.default, value: editSection)
                Text("Drag toolbar items to reorder them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)

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
        
        @ObservedObject var browserState: BrowserState
        @ObservedObject var sidebarStore: SidebarStore
        @ObservedObject var bookmarkStore: BookmarkStore
        
        @Binding var location: URL?
        @Binding var urlInput: String
        @Binding var showTrustInfo: Bool
        @Binding var showTabSearch: Bool
        @Binding var showEventPopup: Bool
        @Binding var showGoTo: Bool
        @Binding var showBoost: Bool
        @Binding var splitURL: String
        @ObservedObject var splitState: BrowserState
        let focusAddressOnAppear: Bool
        let isPrivate: Bool
        let profileIcon: String?
        let profileName: String?
        let events: [EventExtraction]
        @Binding var showReader: Bool
        
        let submitURL: () -> Void
        let scanEvents: () async -> Void
        
        @State var showSuggestions = false
        
        var body: some View {
            switch item {
            case .clock:
                ClockView(timeOnly: true, fontSize: 14)
                
            case .navigation:
                NavigationButtons(location: $location, browserState: browserState)
                
            case .home:
                HomeToolbarButton(location: $location, urlInput: $urlInput)
                
            case .share:
                ShareToolbarButton(location: $location)
                
            case .reload:
                ReloadToolbarButton(browserState: browserState)
                
            case .addressBar:
                AddressBar(
                    browserState: browserState,
                    location: $location,
                    urlInput: $urlInput,
                    showTrustInfo: $showTrustInfo,
                    showTabSearch: $showTabSearch,
                    showEventPopup: $showEventPopup,
                    showGoTo: $showGoTo,
                    focusOnAppear: focusAddressOnAppear,
                    isPrivate: isPrivate,
                    profileIcon: profileIcon,
                    profileName: profileName,
                    events: events,
                    submitURL: submitURL
                )
                
            case .search:
                SearchToolbarButton(location: $location, submitURL: submitURL)
                
            case .autocomplete:
                Button {
                    showSuggestions.toggle()
                } label: {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.title2)
                        .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
                }
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in:.circle)
                .buttonStyle(.plain)
                .popover(isPresented: $showSuggestions) {
                    AutoFillPopover(searchTerm: $urlInput)
                }
                
            case .extensions:
                ExtensionsToolbarButton(browserState: browserState, location: $location)
                
            case .saveTo:
                SaveToToolbarButton(location: $location, sidebarStore: sidebarStore, bookmarkStore: bookmarkStore)
                
            case .splitView:
                SplitViewToolbarButton(splitURL: $splitURL, splitState: splitState)
                    .disabled(location == nil)
                
            case .reader:
                Button {
                    showReader.toggle()
                } label: {
                    Image(systemName: "eyeglasses")
                        .font(.title2)
                        .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
                }
                .glassEffect(.regular.interactive(), in:.circle)
                .buttonStyle(.plain)
                .disabled(location == nil)
                
            case .spacer:
                Color.clear
                    .frame(
                        minWidth: Layout.toolbarButtonSize,
                        maxWidth: .infinity
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
                            browserState: browserState,
                            sidebarStore: sidebarStore,
                            bookmarkStore: bookmarkStore,
                            location: $location,
                            urlInput: $urlInput,
                            showTrustInfo: $showTrustInfo,
                            showTabSearch: $showTabSearch,
                            showEventPopup: $showEventPopup,
                            showGoTo: $showGoTo,
                            showBoost: $showBoost,
                            splitURL: $splitURL,
                            splitState: splitState,
                            focusAddressOnAppear: focusAddressOnAppear,
                            isPrivate: isPrivate,
                            profileIcon: profileIcon,
                            profileName: profileName,
                            events: events,
                            showReader: $showReader,
                            submitURL: submitURL,
                            scanEvents: scanEvents
                        )
                    )
                }
            case .commandPalette:
                CommandPaletteToolbarButton(urlInput: $urlInput)
                
            case .findInPage:
                FindInPageToolbarButton(browserState: browserState)
                
            case .ai:
                AIMenuToolbar(browserState: browserState, location: $location, scanEvents: scanEvents)
            case .restyle:
                RestyleToolbarButton(showBoost: $showBoost)
                    .disabled(location == nil)
            case .mute:
                MuteToolbar(location: $location, browserState: browserState)
            case .duplicate:
                DuplicateToolbarButton(location: $location)
            case .rename:
                RenameToolbar(location: $location, browserState: browserState)
            case .zoom:
                ZoomToolbar(location: $location, browserState: browserState)
            }
        }
        
        
    }
}

private struct ToolbarDragSource: ViewModifier {
    let entry: ToolbarEntry
    @Binding var draggedItemID: UUID?
    
    @AppStorage("showToolbarDragHandle") private var showDrag = true

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
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.data.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(entry.id.uuidString.data(using: .utf8), nil)
            return nil
        }
        return provider
    }
}
