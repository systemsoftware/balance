import SwiftUI
import WebKit
import SwiftData
internal import UniformTypeIdentifiers

enum CommandSection: String, CaseIterable, Identifiable, Codable {
    case tabs, bookmarks, search, commands, history
    var id: String { rawValue }
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
}

struct Profile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var imapHost: String?
    var imapPort: UInt16?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "person.crop.circle",
        imapHost: String? = nil,
        imapPort: UInt16? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.imapHost = imapHost
        self.imapPort = imapPort
    }
}

struct CommandsView: View {
    enum Screen: Equatable {
        case commands
        case profiles
        case enterURL(privateMode: Bool)
    }
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var screen: Screen = .commands
    @Binding var searchText: String
    
    @Query(sort: \HistoryItem.timestamp, order: .reverse)
    private var historyItems: [HistoryItem]
    
    @State private var bookmarkStore = BookmarkStore()
    
    var showData = true
    
    let commands: [Command] = [
        .init(name: "New Tab",
              systemImage: "plus.square.on.square",
              action: .newTab, showsChevron:false),
        
            .init(name: "New Window",
                  systemImage: "macwindow.badge.plus",
                  action: .newWindow, showsChevron:false),
        
            .init(name: "New Private Window",
                  systemImage: "eye.slash.fill",
                  action: .newPrivateWindow, showsChevron:false),
        
            .init(name: "New Window At...",
                  systemImage: "macwindow.badge.plus",
                  action: .newWindowAt, showsChevron:true),
        
            .init(name: "New Private Window At...",
                  systemImage: "eye.slash.fill",
                  action: .newPrivateWindowAt, showsChevron:true),
        
            .init(name: "New Window With Profile...",
                  systemImage: "person.fill",
                  action: .newWindowWithProfile, showsChevron:true),
    ]
    
    var filteredCommands: [Command] {
        if searchText.isEmpty {
            commands
        } else {
            commands.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty {
            return bookmarkStore.items
        }
        
        return bookmarkStore.items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var filteredHistory: [HistoryItem] {
        if searchText.isEmpty {
            return historyItems
        }
        
        return historyItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var filteredTabs: [BrowserState] {
        let states = WindowManager.shared.windows
        if searchText.isEmpty {
            return states
        } else {
            return states.filter { state in
                state.title.localizedCaseInsensitiveContains(searchText) ||
                (state.url?.absoluteString.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    @State private var urlString = ""
    @State private var showNewProfile = false
    @State private var hideProfileList = false
    
    @AppStorage("paletteShowTabs", store:Config.sharedDefaults) var showTabs: Bool = true
    @AppStorage("paletteShowBookmarks", store:Config.sharedDefaults) var showBookmarks: Bool = true
    @AppStorage("paletteShowSearch", store:Config.sharedDefaults) var showSearch: Bool = true
    @AppStorage("paletteShowCommands", store:Config.sharedDefaults) var showCommands: Bool = true
    @AppStorage("paletteShowHistory", store:Config.sharedDefaults) var showHistory: Bool = true
    
    @Binding var searchQuery: String
    
    @AppStorage("paletteSectionOrder", store: Config.sharedDefaults) private var sectionOrderJSON = "[\"tabs\",\"bookmarks\",\"search\",\"commands\",\"history\"]"
    
    private var sectionOrder: [CommandSection] {
        if let data = sectionOrderJSON.data(using: .utf8),
           let order = try? JSONDecoder().decode([CommandSection].self, from: data) {
            return order
        }
        return CommandSection.allCases
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
    
    @State private var draggingSection: CommandSection?
    
    @ViewBuilder
    private func sectionHeader(title: String, section: CommandSection) -> some View {
        HStack {
            Text(title)
            Spacer()
        }
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onDrag {
            self.draggingSection = section
            return NSItemProvider(object: section.rawValue as NSString)
        }
        .onDrop(of: [.plainText], delegate: SectionDropDelegate(item: section, items: sectionOrderBinding, draggedItem: $draggingSection))
    }
    
    @ViewBuilder
    private var tabsSection: some View {
        if (!showData || (searchText.isEmpty ? filteredTabs.count > 1 : !filteredTabs.isEmpty)) && showTabs {
            Section(header: sectionHeader(title: "Tabs", section: .tabs)) {
                if showData {
                    ForEach(filteredTabs, id: \.tabID) { state in
                        Button(action: {
                            switchToTab(tabID: state.tabID)
                            dismiss()
                        }) {
                            row(
                                title: state.title.isEmpty ? "Untitled Tab" : state.title,
                                image: "macwindow",
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var bookmarksSection: some View {
        if (!showData || !filteredBookmarks.isEmpty) && showBookmarks {
            Section(header: sectionHeader(title: "Bookmarks", section: .bookmarks)) {
                if showData {
                    ForEach(filteredBookmarks) { mark in
                        Button {
                            createNewTab(with: URL(string:mark.url))
                            dismiss()
                        } label: {
                            row(
                                title: mark.title,
                                image: "bookmark",
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var searchSection: some View {
        if showSearch {
            Section(header: sectionHeader(title: "Search", section: .search)) {
                if showData {
                    AutoFillView(searchTerm: $searchText, noContentAvView:true,
                                 updateOther: Binding<String?>(
                                    get: { searchQuery },
                                    set: { searchQuery = $0 ?? "" }
                                 )
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var commandsSection: some View {
        if (!showData || !filteredCommands.isEmpty) && showCommands {
            Section(header: sectionHeader(title: "Commands", section: .commands)) {
                if showData {
                    ForEach(filteredCommands) { command in
                        Button {
                            perform(command.action)
                        } label: {
                            row(
                                title: command.name,
                                image: command.systemImage,
                                showsChevron: command.showsChevron
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var historySection: some View {
        if (!showData || !filteredHistory.isEmpty) && showHistory {
            Section(header: sectionHeader(title: "History", section: .history)) {
                if showData {
                    ForEach(filteredHistory) { historyItem in
                        Button {
                            guard let url = URL(string: historyItem.url) else { return }
                            createNewTab(with: url)
                            dismiss()
                        } label: {
                            row(
                                title: historyItem.title,
                                image: "arrow.up.circle",
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var commandsScreen: some View {
        Section {
            ForEach(sectionOrder) { section in
                switch section {
                case .tabs: tabsSection
                case .bookmarks: bookmarksSection
                case .search: searchSection
                case .commands: commandsSection
                case .history: historySection
                }
            }
        }
    }

    @ViewBuilder
    private var profilesScreen: some View {
        ProfileView(searchText: $searchText, hideProfileList: $hideProfileList, showNewProfile: $showNewProfile)
        
        HStack {
            Button("Cancel") {
                urlString = ""
                showNewProfile = false
                screen = .commands
            }
            .padding(.trailing, 3)
            
            if !showNewProfile {
                Button("Create Profile") {
                    showNewProfile = true
                }
            }
        }
        .padding(.top)
    }

    @ViewBuilder
    private func enterURLScreen(privateMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open URL")
                .font(.headline)
            
            TextField("https://example.com", text: $urlString)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    urlString = ""
                    screen = .commands
                }
                
                Button("Open") {
                    createNewWindow(
                        with: URL(string: urlString),
                        pvt: privateMode
                    )
                    dismiss()
                }
                .disabled(urlString.isEmpty)
            }
        }
        .padding()
    }

    @ViewBuilder
    var contentList: some View {
        List {
            switch screen {
            case .commands:
                commandsScreen
            case .profiles:
                profilesScreen
            case .enterURL(let privateMode):
                enterURLScreen(privateMode: privateMode)
            }
        }
        .listStyle(.inset)
        .navigationTitle(screen == .commands ? "Palette" : "Select Profile")
        
        .toolbar {
            if screen == .profiles {
                ToolbarItem(placement: .navigation) {
                    Button {
                        searchText = ""
                        screen = .commands
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 350)
    }
    
    var body: some View {
        if showData {
            contentList
                .searchable(
                    text: $searchText,
                    prompt: screen == .commands ? "Search" : screen == .profiles ? "Search profiles" : "Cannot search"
                )
        } else {
            contentList
        }
    }
    
    
    private func perform(_ action: Command.Action) {
        switch action {
        case .newTab:
            createNewTab()
            dismiss()
            
        case .newWindow:
            createNewWindow()
            dismiss()
            
        case .newPrivateWindow:
            createNewWindow(pvt: true)
            dismiss()
            
        case .newWindowAt:
            searchText = ""
            screen = .enterURL(privateMode: false)
            
        case .newPrivateWindowAt:
            searchText = ""
            screen = .enterURL(privateMode: true)
            
        case .newWindowWithProfile:
            searchText = ""
            screen = .profiles
            showNewProfile = false
            hideProfileList = false
        case .newProfile:
            screen = .profiles
            showNewProfile = true
            hideProfileList = true
        }
    }

}


struct ProfileView: View {
    
    
    @AppStorage("profiles", store: Config.sharedDefaults)
    private var profilesJSON = "[]"
    
    @Environment(\.dismiss) var dismiss
        
    private var profiles: [Profile] {
        get {
            (try? JSONDecoder().decode([Profile].self,
                                       from: Data(profilesJSON.utf8))) ?? []
        }
        set {
            profilesJSON = String(
                data: try! JSONEncoder().encode(newValue),
                encoding: .utf8
            )!
        }
    }
    
    @State var nameInput: String = ""
    @State var iconInput: String = ""
    @State var imapHostInput: String = ""
    @State var imapPortInput: String = "993"
    @State var imapEmailInput: String = ""
    @State var imapPasswordInput: String = ""
    
    @Binding var searchText: String
    
    @Binding var hideProfileList: Bool
    @Binding var showNewProfile: Bool
    
    @State var showAdvancedIcon = false
    
    @State var showIMAP = false
    
    
    var showHeader = true
    
    var filteredProfiles: [Profile] {
        if searchText.isEmpty {
            return profiles
        }
        
        return profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Section {
            if !hideProfileList {
                if !filteredProfiles.isEmpty {
                    ForEach(filteredProfiles) { profile in
                        Button {
                            createNewWindow(profile: profile.id.uuidString, profileIcon:profile.icon.isEmpty ? "person.fill" : profile.icon)
                            dismiss()
                        } label: {
                            row(
                                title: profile.name,
                                image: profile.icon.isEmpty ? "person.fill" : profile.icon,
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteProfile(profile)
                            } label: {
                                Label("Delete Profile", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    row(
                        title: "No Profiles",
                        image: "person.slash.fill",
                    )
                    .foregroundStyle(.gray)
                }
            }
        } header: {
            if showHeader {
                Text("Profile")
            }
        }
        .sheet(isPresented: $showNewProfile) {
                            Section {
                    VStack(alignment: .leading, spacing: 10) {
                        
                        Text("New Profile")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $nameInput)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack {
                                Text("Icon")
                                
                                Spacer()
                                
                                Picker("", selection: $iconInput) {
                                    Text("Default").tag("")
                                    Text("Person").tag("person.crop.circle")
                                    Text("Briefcase").tag("briefcase.fill")
                                    Text("Graduation Cap").tag("graduationcap.fill")
                                    Text("Book").tag("book.fill")
                                    Text("Globe").tag("globe")
                                    Text("Star").tag("star.fill")
                                    Text("Heart").tag("heart.fill")
                                    Text("Gamepad").tag("gamecontroller.fill")
                                    Text("Terminal").tag("terminal.fill")
                                }
                            }
                            
                            Button("Advanced Icon") {
                                showAdvancedIcon.toggle()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            
                            if showAdvancedIcon {
                                TextField("SF Symbol", text: $iconInput)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            if showIMAP { Divider() }
                            Button("Email Settings (Optional)"){
                                showIMAP.toggle()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                            
                            if showIMAP {
                                TextField("IMAP Host (e.g. imap.gmail.com)", text: $imapHostInput)
                                .textFieldStyle(.roundedBorder)
                                TextField("IMAP Port (e.g. 993)", text: $imapPortInput)
                                .textFieldStyle(.roundedBorder)
                                TextField("Email Address", text: $imapEmailInput)
                                .textFieldStyle(.roundedBorder)
                                SecureField("Password", text: $imapPasswordInput)
                                .textFieldStyle(.roundedBorder)
                        }
                        }
                        
                        Button {
                            guard !nameInput.isEmpty else { return }
                            let port = UInt16(imapPortInput)
                            addProfile(
                                name: nameInput,
                                icon: iconInput.isEmpty ? "person.crop.circle" : iconInput,
                                imapHost: imapHostInput.isEmpty ? nil : imapHostInput,
                                imapPort: port,
                                imapEmail: imapEmailInput.isEmpty ? nil : imapEmailInput,
                                imapPassword: imapPasswordInput.isEmpty ? nil : imapPasswordInput
                            )
                            
                            nameInput = ""
                            iconInput = ""
                            imapHostInput = ""
                            imapPortInput = "993"
                            imapEmailInput = ""
                            imapPasswordInput = ""
                            showNewProfile = false
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Profile")
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(nameInput.isEmpty)
                        
                        Button() {
                            showNewProfile = false
                        } label: {
                            HStack {
                                Image(systemName: "xmark")
                                Text("Cancel")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
            }

        }
    }
    
    private func addProfile(name: String, icon: String, imapHost: String? = nil, imapPort: UInt16? = nil, imapEmail: String? = nil, imapPassword: String? = nil) {
        var current = (try? JSONDecoder().decode(
            [Profile].self,
            from: Data(profilesJSON.utf8)
        )) ?? []
        
        let newProfile = Profile(name: name, icon: icon, imapHost: imapHost, imapPort: imapPort)
        current.append(newProfile)
        
        profilesJSON = String(
            data: try! JSONEncoder().encode(current),
            encoding: .utf8
        )!
        
        if let email = imapEmail, let password = imapPassword {
            PasswordManager.shared.savePassword(
                username: email,
                passwordString: password,
                domain: "balance.profile.imap.\(newProfile.id.uuidString)"
            )
        }
    }
    
    
    
    private func deleteProfile(_ profile: Profile) {
        
        var current = (try? JSONDecoder().decode(
            [Profile].self,
            from: Data(profilesJSON.utf8)
        )) ?? []
        
        current.removeAll { $0.id == profile.id }
        
        profilesJSON = String(
            data: try! JSONEncoder().encode(current),
            encoding: .utf8
        )!
        
        if #available(macOS 14.0, *) {
            WKWebsiteDataStore.remove(forIdentifier: profile.id) { error in
                if let error = error {
                    print("Failed to remove profile data store: \(error)")
                } else {
                    print("Profile data wiped completely")
                }
            }
        } else {
            let store = WKWebsiteDataStore(forIdentifier: profile.id)
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            store.fetchDataRecords(ofTypes: types) { records in
                store.removeData(ofTypes: types, for: records) {
                    print("Profile data cleared")
                }
            }
        }
    }
}

@ViewBuilder
func row(
    title: String,
    image: String,
    showsChevron: Bool = false
) -> some View {
    HStack(spacing: 10) {
        Image(systemName: image)
            .foregroundStyle(.secondary)
            .frame(width: 18)
        
        Text(title)
        
        Spacer()
        
        if showsChevron {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    .padding(.vertical, 6)
}
