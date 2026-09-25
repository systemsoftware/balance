import Foundation
import SwiftUI
import WebKit
internal import UniformTypeIdentifiers


// MARK: - Tabs

struct Tabs: View {

    var browserState: BrowserState
    var alignsWithTitlebar = false
    var compactAddressBar: AnyView? = nil

    @StateObject private var store = PinStore()
    @EnvironmentObject var windowManager: WindowManager

    @State private var searchText = ""
    @State private var hoveredID: ObjectIdentifier?
    @State private var draggedPin: Bookmark?
    @State private var draggedTab: BrowserState?
    @State private var tabFrames: [String: CGRect] = [:]
    
    @AppStorage("tabMode", store:Config.sharedDefaults) var tabMode = 0
    
    @AppStorage("showSpaces", store:Config.sharedDefaults) var showSpaces = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    private var currentWindowTabs: [BrowserState] {
        let tabs = windowManager.tabs(inSameWindowAs: browserState.tabID)
        return tabs.isEmpty ? [browserState] : tabs
    }

    private var filteredTabs: [BrowserState] {
        let spaceFiltered = currentWindowTabs.filter { $0.spaceIndex == windowManager.currentSpaceIndex }
        guard !searchText.isEmpty else { return spaceFiltered }
        return spaceFiltered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.url?.absoluteString.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    @AppStorage("tabBackground", store:Config.sharedDefaults) var tabBackground = true
    @AppStorage("showNewTabButton", store:Config.sharedDefaults) var showNewTabButton = true
    
    var body: some View {
        VStack(spacing: 0) {
            if tabMode != 0 && tabMode != 4 && tabMode != 5 {
                // MARK: Header
                VStack(spacing: 12) {
                    if tabMode == 1 {
                        HStack {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("Tabs")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(currentWindowTabs.count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15), in:BackgroundShape())
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        
                        
                        // Search field
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                            TextField("Search tabs…",
                                text: $searchText,
                            )
                            .textFieldStyle(.plain)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .glassEffect()
                        
                        
                        Divider()
                            .opacity(0.3)
                            .padding(.top, 10)
                    }
                
                }
                
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // MARK: Pinned Section
                        if !store.items.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(store.items) { bookmark in
                                            PinnedSiteButton(bookmark: bookmark, pinStore: store)
                                                .onDrag {
                                                    self.draggedPin = bookmark
                                                    return NSItemProvider(object: bookmark.id.uuidString as NSString)
                                                }
                                                .onDrop(of: [UTType.text], delegate: PinDropDelegate(item: bookmark, store: store, draggedItem: $draggedPin))
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 4)
                                }
                            }
                            
                            Divider()
                                .opacity(0.25)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        
                        // MARK: Open Tabs Section
                        VStack(alignment: .leading, spacing: 2) {
                            if store.items.isEmpty {
                                SectionLabel(title: windowManager.spaceNames.indices.contains(windowManager.currentSpaceIndex) ? windowManager.spaceNames[windowManager.currentSpaceIndex] : "Space \(windowManager.currentSpaceIndex + 1)", count: filteredTabs.count)
                                    .padding(.top)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)
                            } else {
                                SectionLabel(title: windowManager.spaceNames.indices.contains(windowManager.currentSpaceIndex) ? windowManager.spaceNames[windowManager.currentSpaceIndex] : "Space \(windowManager.currentSpaceIndex + 1)", count: filteredTabs.count)
                                    .padding(.top)
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 4)
                            }
                            
                            if filteredTabs.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundStyle(.tertiary)
                                    Text("No tabs here")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                            } else {
                                ForEach(filteredTabs, id: \.self) { tab in
                                    TabRow(
                                        state: tab,
                                        isActive: tab === browserState,
                                        isHovered: hoveredID == ObjectIdentifier(tab),
                                        pinStore: store,
                                        applyGlass:true,
                                        animateInsertion: tab.shouldAnimateTabInsertion
                                    )
                                    .padding(.horizontal, 8)
                                    .onHover { over in
                                        withAnimation(.easeInOut(duration: 0.12)) {
                                            hoveredID = over ? ObjectIdentifier(tab) : nil
                                        }
                                    }
                                    .background(tabFrameReader(for: tab))
                                    .simultaneousGesture(tabReorderGesture(for: tab))
                                }
                                Spacer()
                                if showNewTabButton {
                                    HStack {
                                        Spacer()
                                        Button {
                                            createNewTab()
                                        } label: {
                                            Image(systemName: "plus")
                                        }
                                        .buttonStyle(.plain)
                                        .padding(7)
                                        .glassEffect()
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 10)
                    }
                }
                
                if showSpaces {
                    VStack(spacing: 8) {
                        Divider().opacity(0.3)
                        HStack(spacing: 12) {
                            ForEach(Array(windowManager.spaceNames.enumerated()), id: \.offset) { index, spaceName in
                                Circle()
                                    .fill(windowManager.currentSpaceIndex == index ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .onTapGesture {
                                        withAnimation {
                                            windowManager.currentSpaceIndex = index
                                        }
                                    }
                                    .contextMenu {
                                        Button("Rename Space") {
                                            promptRenameSpace(at: index)
                                        }
                                        if windowManager.spaceNames.count > 1 {
                                            Button("Remove Space", role: .destructive) {
                                                windowManager.removeSpace(at: index)
                                            }
                                        }
                                        
                                        Toggle("Show Spaces", isOn: $showSpaces)

                                    }
                                    .help(spaceName)
                                
                            }
                            
                            Button {
                                withAnimation {
                                    windowManager.spaceNames.append("Space \(windowManager.spaceNames.count + 1)")
                                    windowManager.currentSpaceIndex = windowManager.spaceNames.count - 1
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("New Space")
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color.clear)
                }
            } else {
                HStack {
                    if showSpaces {
                        
                        Menu {
                            ForEach(Array(windowManager.spaceNames.enumerated()), id: \.offset) { index, spaceName in
                                Button {
                                    withAnimation { windowManager.currentSpaceIndex = index }
                                } label: {
                                    if windowManager.currentSpaceIndex == index {
                                        Label(spaceName, systemImage: "checkmark")
                                    } else {
                                        Text(spaceName)
                                    }
                                }
                            }
                            Divider()
                            Button("New Space") {
                                withAnimation {
                                    windowManager.spaceNames.append("Space \(windowManager.spaceNames.count + 1)")
                                    windowManager.currentSpaceIndex = windowManager.spaceNames.count - 1
                                }
                            }
                            Button("Rename Space") {
                                promptRenameSpace(at: windowManager.currentSpaceIndex)
                            }
                            if windowManager.spaceNames.count > 1 {
                                Button("Remove Space", role: .destructive) {
                                    windowManager.removeSpace(at: windowManager.currentSpaceIndex)
                                }
                            }
                        } label: {
                            Image(systemName: "rectangle.on.rectangle.angled")
                        }
                        .menuStyle(.borderlessButton)
                        .padding(.leading, tabMode == 5 ? 10 : 0)
                        .contextMenu {
                            Toggle("Show Spaces", isOn: $showSpaces)
                            
                            Button("Rename Space") {
                                promptRenameSpace(at: windowManager.currentSpaceIndex)
                            }
                            
                            if windowManager.spaceNames.count > 1 {
                                Button("Remove Space", role: .destructive) {
                                    let index = windowManager.currentSpaceIndex
                                    windowManager.removeSpace(at: index)
                                }
                            }
                            
                        }
                        if compactAddressBar == nil { Spacer() }
                    }
                    if compactAddressBar != nil {
                        GeometryReader { geometry in
                            compactTabStrip(width: geometry.size.width)
                        }
                        .frame(height: 40)
                    } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isCompact ? 4 : 6) {
                            ForEach(filteredTabs, id: \.self) { tab in
                                TabRow(
                                    state: tab,
                                    isActive: tab === browserState,
                                    isHovered: hoveredID == ObjectIdentifier(tab),
                                    pinStore: store,
                                    showURL:false,
                                    animateInsertion: tab.shouldAnimateTabInsertion
                                )
                                .frame(minWidth: isCompact ? 90 : 120, maxWidth: isCompact ? 160 : 220)
                                .onHover { over in
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        hoveredID = over ? ObjectIdentifier(tab) : nil
                                    }
                                }
                                .background(tabFrameReader(for: tab))
                                .simultaneousGesture(tabReorderGesture(for: tab))
                            }
                            
                            if showNewTabButton {
                                Button {
                                    createNewTab()
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.primary)
                                .padding(7)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 0.7)
                    .background {
                        BackgroundShape()
                            .fill(.clear)
                            .glassEffect(
                                tabBackground ? .regular : .identity,
                                in: BackgroundShape()
                            )
                            .allowsHitTesting(false)
                    }
                    .padding(.horizontal, Layout.controlPadding)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.top, alignsWithTitlebar || compactAddressBar != nil ? 0 : 16)
            }
        }
        
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .glassEffect(
                    tabBackground && tabMode == 2 ? .regular : .identity,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: compactAddressBar == nil ? .infinity : nil)
        .onPreferenceChange(TabFramePreferenceKey.self) { tabFrames = $0 }
            
    }

    private func compactTabStrip(width: CGFloat) -> some View {
        let tabs = filteredTabs
        let reservedWidth: CGFloat = 260 + (showNewTabButton ? 30 : 0) + (tabs.count > 1 ? 32 : 0)
        let visibleCount = min(tabs.count, max(1, 1 + Int(max(0, width - reservedWidth) / 120)))
        let activeIndex = tabs.firstIndex { $0 === browserState } ?? 0
        let start = min(max(0, activeIndex - visibleCount / 2), max(0, tabs.count - visibleCount))
        let visible = Array(tabs.dropFirst(start).prefix(visibleCount))
        let hidden = tabs.filter { tab in !visible.contains { $0 === tab } }

        return
            HStack(spacing: 4) {
                
                    ForEach(visible.filter { $0 !== browserState }, id: \.self) { tab in
                        if (tabs.firstIndex { $0 === tab } ?? 0) < activeIndex {
                            compactTab(tab)
                        }
                    }
            
            if let compactAddressBar {
                compactAddressBar
                    .frame(minWidth: 220, maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.08), in: Capsule())
            }
            
                    ForEach(visible.filter { $0 !== browserState }, id: \.self) { tab in
                        if (tabs.firstIndex { $0 === tab } ?? 0) > activeIndex {
                            compactTab(tab)
                        }
                    }
            
            if !hidden.isEmpty {
                Menu {
                    ForEach(hidden, id: \.self) { tab in
                        Button {
                            switchToTab(tabID: tab.tabID)
                        } label: {
                            Text(tab.title.isEmpty ? "New Tab" : tab.title)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 24, height: 32)
                }
                .menuStyle(.borderlessButton)
                .help("More Tabs")
                .padding(.trailing, showNewTabButton ? 0 : 4)
            }
            
            if showNewTabButton {
                Button {
                    createNewTab()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 32)
                }
                .buttonStyle(.plain)
                .help("New Tab")
                .padding(.trailing, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.18), value: visible.map(\.tabID))
    }

    private func compactTab(_ tab: BrowserState) -> some View {
        TabRow(
            state: tab,
            isActive: false,
            isHovered: hoveredID == ObjectIdentifier(tab),
            pinStore: store,
            showURL: false,
            animateInsertion: tab.shouldAnimateTabInsertion
        )
        .frame(width: 112)
        .onHover { hoveredID = $0 ? ObjectIdentifier(tab) : nil }
        .background(tabFrameReader(for: tab))
        .simultaneousGesture(tabReorderGesture(for: tab))
    }

    private func tabFrameReader(for tab: BrowserState) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TabFramePreferenceKey.self,
                value: [tab.tabID: proxy.frame(in: .global)]
            )
        }
    }

    private func tabReorderGesture(for tab: BrowserState) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                draggedTab = tab
                guard let target = nearestTab(to: value.location), target !== tab else { return }
                windowManager.moveTab(tab.tabID, toTabID: target.tabID)
            }
            .onEnded { _ in
                draggedTab = nil
            }
    }

    private func nearestTab(to location: CGPoint) -> BrowserState? {
        filteredTabs.filter { tabFrames[$0.tabID] != nil }.min { lhs, rhs in
            guard let lhsFrame = tabFrames[lhs.tabID],
                  let rhsFrame = tabFrames[rhs.tabID] else { return false }
            let lhsDistance = tabMode == 0 || tabMode == 5
                ? abs(lhsFrame.midX - location.x)
                : abs(lhsFrame.midY - location.y)
            let rhsDistance = tabMode == 0 || tabMode == 5
                ? abs(rhsFrame.midX - location.x)
                : abs(rhsFrame.midY - location.y)
            return lhsDistance < rhsDistance
        }
    }

    private func promptRenameSpace(at index: Int) {
        guard windowManager.spaceNames.indices.contains(index) else { return }
        let currentName = windowManager.spaceNames[index]
#if canImport(AppKit)
        let alert = NSAlert()
        alert.informativeText = "Enter new space name:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.stringValue = currentName
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        if alert.runModal() == .alertFirstButtonReturn {
            let val = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            windowManager.renameSpace(at: index, to: val)
        }
#else
        SwiftUIPresentationCenter.shared.prompt(
            "Rename Space",
            message: "Enter a new space name.",
            placeholder: currentName,
            initialText: currentName,
            primaryTitle: "Rename"
        ) { value in
            guard let value else { return }
            let val = value.trimmingCharacters(in: .whitespacesAndNewlines)
            windowManager.renameSpace(at: index, to: val)
        }
#endif
    }
}

private struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}


// MARK: - Drop Delegate

struct PinDropDelegate: DropDelegate {
    let item: Bookmark
    var store: PinStore
    @Binding var draggedItem: Bookmark?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = self.draggedItem else { return }
        guard draggedItem != item else { return }
        
        guard let from = store.items.firstIndex(of: draggedItem),
              let to = store.items.firstIndex(of: item) else {
            self.draggedItem = nil
            return
        }
        
        withAnimation {
            store.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
}

// MARK: - Section Label

private struct SectionLabel: View {
    let title: String
    let count: Int
    var body: some View {
        HStack(spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.8)
            Text("\(count)")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.quaternary)
        }
    }
}


// MARK: - Pinned Site Button

private struct PinnedSiteButton: View {
    let bookmark: Bookmark
    let pinStore: PinStore
    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = URL(string: bookmark.url) {
                createNewTab(with: url)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(isHovered ? 0.18 : 0.1))
                        .frame(width: 40, height: 40)
                    Favicon(bookmark.url)
                    .frame(width: 22, height: 22)
                }
                .scaleEffect(isHovered ? 1.06 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)

            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Remove Pin") {
                pinStore.remove(url: bookmark.url)
            }
        }
    }
}


// MARK: - Tab Row

private struct TabRow: View {
    @ObservedObject var state: BrowserState
    let isActive: Bool
    let isHovered: Bool
    var pinStore: PinStore
    var showURL = true
    let animateInsertion: Bool
    @EnvironmentObject var windowManager: WindowManager
    @State private var insertionFinished: Bool
    @State private var faviconURL: URL?

    var glass = false
    
    @State var showTrail = false
    
    @AppStorage("tabMode", store:Config.sharedDefaults) var tabMode = 0

    init(
        state: BrowserState,
        isActive: Bool,
        isHovered: Bool,
        pinStore: PinStore,
        showURL: Bool = true,
        applyGlass: Bool = false,
        animateInsertion: Bool = false,
    ) {
        self.state = state
        self.isActive = isActive
        self.isHovered = isHovered
        self.pinStore = pinStore
        self.showURL = showURL
        self.animateInsertion = animateInsertion
        self.glass = applyGlass
        self._insertionFinished = State(initialValue: !animateInsertion)
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if state.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    if let host = state.url?.host, !host.isEmpty {
                        CachedAsyncImage(url: faviconURL ?? Favicon.full(host))
                            .frame(width: 16, height: 16)
                            .task(id: state.url) {
                                faviconURL = await state.tryGetFavicon()
                            }
                    } else{
                        Image(systemName: "house")
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .frame(width: 16, height: 16)

            // Title + URL
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(state.title.isEmpty ? "New Tab" : state.title)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
                    
                    if state.isSleeping {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                if let url = state.url {
                    if showURL {
                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Audio indicator
            if state.isAudioMuted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
            
            Button {
                windowManager.closeTab(state.tabID)
            } label:{
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .font(.caption)
            
            
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background {
            if isActive {
                BackgroundShape()
                    .fill(.tint)
                    .opacity(glass ? 0.0 : 0.18)
                    .glassEffect(
                        glass ? .regular : .identity,
                        in: BackgroundShape()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(.tint, lineWidth: 1)
                            .opacity(glass ? 0.0 : 0.35)
                    )
            } else if isHovered {
                BackgroundShape()
                    .fill(.secondary)
                    .opacity(0.1)
            } else {
                Color.clear
            }
        }
        .contentShape(BackgroundShape())
        .offset(
            x: insertionFinished || tabMode != 0 ? 0 : 80,
            y: insertionFinished || tabMode == 0 ? 0 : 24
        )
        .scaleEffect(insertionFinished ? 1 : 0.94)
        .opacity(insertionFinished ? 1 : 0)
        .onAppear {
            guard animateInsertion, !insertionFinished else { return }
            Task { @MainActor in
                // Allow the initial offset/opacity to render before transitioning.
                // Updating immediately in onAppear is coalesced into the first frame.
                await Task.yield()
                state.shouldAnimateTabInsertion = false
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82)) {
                    insertionFinished = true
                }
            }
        }
        .onTapGesture {
            switchToTab(tabID: state.tabID)
        }
        .sheet(isPresented: $showTrail) {
            TrailView(tabState: state)
                .frame(minWidth: 500, minHeight: 400)
        }
        .contextMenu {

            Text(state.title)
                .disabled(true)
            
            Divider()
            
            Button("Focus Tab") {
                switchToTab(tabID: state.tabID)
            }
            
            Button(state.isSleeping ? "Wake Tab" : "Sleep Tab") {
                state.isSleeping.toggle()
            }

            if tabMode == 1 || tabMode == 2 {
                if pinStore.items.first(where: { $0.url == state.url?.absoluteString }) == nil {
                    Button("Pin Tab") {
                        pinStore.add(Bookmark(
                            title: state.title,
                            url: state.url?.absoluteString ?? ""
                        ))
                    }
                } else {
                    Button("Unpin Tab") {
                        pinStore.remove(url: state.url?.absoluteString ?? "")
                    }
                }
            }
            
            Divider()

            Button("Copy URL") {
                if let url = state.url?.absoluteString {
                    PlatformApplication.copy(url)
                }
            }
            
            Divider()
            
            Button("Close") {
                windowManager.closeTab(state.tabID)
            }
            
            Divider()
            
            Menu("Move to Space") {
                ForEach(Array(windowManager.spaceNames.enumerated()), id: \.offset) { index, spaceName in
                    if index != state.spaceIndex {
                        Button(spaceName) {
                            withAnimation {
                                state.spaceIndex = index
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Trail") {
                showTrail.toggle()
            }
        }
    }
}

struct TrailView: View {
    @ObservedObject var tabState: BrowserState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var trail: [String] {
        guard let webView = tabState.webView else { return [] }
        let backList = webView.backForwardList.backList
        return backList.map { $0.url.absoluteString }
    }

    var filteredTrail: [String] {
        guard !searchText.isEmpty else { return trail }
        return trail.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !trail.isEmpty {
                searchBar
                Divider()
            }

            if trail.isEmpty {
                emptyState
            } else if filteredTrail.isEmpty {
                noResultsState
            } else {
                trailList
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trail")
                    .font(.headline)
                Text(tabState.title.isEmpty ? "New Tab" : tabState.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("Search trail", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - List

    private var trailList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(filteredTrail.enumerated()), id: \.element) { index, urlString in
                    TrailRow(index: index + 1, urlString: urlString) {
                        guard let url = URL(string: urlString) else { return }
                        createNewTab(with: url)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "signpost.right")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No trail yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Pages you've visited on this tab will show up here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No matches for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct TrailRow: View {
    let index: Int
    let urlString: String
    let action: () -> Void

    @State private var isHovering = false

    private var host: String {
        URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "") ?? urlString
    }

    private var path: String {
        guard let url = URL(string: urlString) else { return "" }
        let p = url.path
        return p.isEmpty || p == "/" ? "" : p
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 18, alignment: .trailing)

                Favicon(urlString)

                VStack(alignment: .leading, spacing: 1) {
                    Text(host)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !path.isEmpty {
                        Text(path)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if isHovering {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.secondary.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
