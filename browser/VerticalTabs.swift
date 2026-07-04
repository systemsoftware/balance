import Foundation
import SwiftUI
internal import UniformTypeIdentifiers


// MARK: - VerticalTabs

struct VerticalTabs: View {

    var browserState: BrowserState
    var profile: String

    @StateObject private var store = PinStore()
    @EnvironmentObject var windowManager: WindowManager

    @State private var searchText = ""
    @State private var hoveredID: ObjectIdentifier?
    @State private var draggedPin: Bookmark?

    private var currentWindowTabs: [BrowserState] {
        let currentID = browserState.tabID
        let groupID = tabGroups[currentID] ?? currentID
        let groupTabIDs = Set(tabGroups.filter { $0.value == groupID }.map { $0.key })
        
        if !groupTabIDs.isEmpty {
            return windowManager.windows.filter { groupTabIDs.contains($0.tabID) }
        }
        
        // Fallback: use native tabbedWindows (when sidebar is off or single tab before any ⌘T)
        guard let currentNSWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == currentID }) else {
            return []
        }
        let tabGroupWindows = currentNSWindow.tabbedWindows ?? [currentNSWindow]
        let validTabIDs = Set(tabGroupWindows.compactMap { $0.identifier?.rawValue })
        return windowManager.windows.filter { validTabIDs.contains($0.tabID) }
    }

    private var filteredTabs: [BrowserState] {
        let spaceFiltered = currentWindowTabs.filter { $0.spaceIndex == windowManager.currentSpaceIndex }
        guard !searchText.isEmpty else { return spaceFiltered }
        return spaceFiltered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.url?.absoluteString.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            VStack(spacing: 12) {
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
                        .background(.secondary.opacity(0.15), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    TextField("Search tabs…", text: $searchText)
                        .font(.system(size: 12))
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
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 10)
            }

            Divider()
                .opacity(0.3)
                .padding(.top, 10)

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
                                    pinStore: store
                                )
                                .padding(.horizontal, 8)
                                .onHover { over in
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        hoveredID = over ? ObjectIdentifier(tab) : nil
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            
            // MARK: Spaces Selector (Circles at bottom)
            VStack(spacing: 8) {
                Divider().opacity(0.3)
                HStack(spacing: 12) {
                    ForEach(0..<windowManager.spaceNames.count, id: \.self) { index in
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
                                    let alert = NSAlert()
                                    alert.informativeText = "Enter new space name:"
                                    alert.addButton(withTitle: "Rename")
                                    alert.addButton(withTitle: "Cancel")
                                    
                                    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
                                    input.stringValue = windowManager.spaceNames[index]
                                    alert.accessoryView = input
                                    alert.window.initialFirstResponder = input
                                    
                                    if alert.runModal() == .alertFirstButtonReturn {
                                        windowManager.spaceNames[index] = input.stringValue.isEmpty ? "Space \(index + 1)" : input.stringValue
                                    }
                                }
                                if windowManager.spaceNames.count > 1 {
                                    Button("Remove Space", role: .destructive) {
                                        // Close tabs in this space and reassign remaining
                                        windowManager.windows.removeAll { $0.spaceIndex == index }
                                        for tab in windowManager.windows {
                                            if tab.spaceIndex > index {
                                                tab.spaceIndex -= 1
                                            }
                                        }
                                        windowManager.spaceNames.remove(at: index)
                                        if windowManager.currentSpaceIndex >= windowManager.spaceNames.count {
                                            windowManager.currentSpaceIndex = windowManager.spaceNames.count - 1
                                        }
                                    }
                                }
                            }
                            .help(windowManager.spaceNames[index])
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        
        let from = store.items.firstIndex(of: draggedItem)!
        let to = store.items.firstIndex(of: item)!
        
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
                NotificationCenter.default.post(
                    name: .openURLInNewTab,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(isHovered ? 0.18 : 0.1))
                        .frame(width: 40, height: 40)
                    AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(URL(string: bookmark.url)?.host ?? "")&sz=64")) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(.secondary)
                        }
                    }
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
    @EnvironmentObject var windowManager: WindowManager

    var body: some View {
        Button {
            switchToTab(tabID: state.tabID)
        } label: {
            HStack(spacing: 8) {
                // Favicon / loading indicator
                ZStack {
                    if state.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(state.url?.host ?? "")")) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 16, height: 16)
                    }
                }
                .frame(width: 16, height: 16)

                // Title + URL
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title.isEmpty ? "New Tab" : state.title)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            //            .foregroundStyle(isActive ? .primary : .primary.opacity(0.85))
                        .lineLimit(1)

                    if let url = state.url {
                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Audio indicator
                if state.isAudioMuted {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(.tint.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(.tint.opacity(0.35), lineWidth: 0.75)
                        )
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(.secondary.opacity(0.1))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Focus Tab") {
                switchToTab(tabID: state.tabID)
            }

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

            Button("Copy URL") {
                if let url = state.url?.absoluteString {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url, forType: .string)
                }
            }
            
            Divider()
            
            Menu("Move to Space") {
                ForEach(0..<windowManager.spaceNames.count, id: \.self) { index in
                    if index != state.spaceIndex {
                        Button(windowManager.spaceNames[index]) {
                            withAnimation {
                                state.spaceIndex = index
                            }
                        }
                    }
                }
            }
        }
    }
}
