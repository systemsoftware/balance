import SwiftUI
import WebKit


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

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "person.crop.circle"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
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
    @State private var searchText = ""
    
    @AppStorage("profiles", store: Config.sharedDefaults)
    private var profilesJSON = "[]"
    
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
        
            .init(name: "New Window At",
                  systemImage: "macwindow.badge.plus",
                  action: .newWindowAt, showsChevron:true),
        
            .init(name: "New Private Window At",
                  systemImage: "eye.slash.fill",
                  action: .newPrivateWindowAt, showsChevron:true),
        
            .init(name: "New Window With Profile",
                  systemImage: "person.fill",
                  action: .newWindowWithProfile, showsChevron:true),
        
            .init(name: "Create Profile",
                  systemImage: "person.fill.badge.plus",
                  action: .newProfile, showsChevron:true)
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
    
    var filteredProfiles: [Profile] {
        if searchText.isEmpty {
            return profiles
        }
        
        return profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    @State private var urlString = ""
    @State private var nameInput = ""
    @State private var iconInput = ""
    @State private var showNewProfile = false
    @State private var hideProfileList = false
    
    var body: some View {
        List {
            switch screen {
            case .commands:
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
                
            case .profiles:
                Section("Profiles") {
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
                }
                
                if showNewProfile {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("New Profile")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(spacing: 8) {
                                TextField("Name", text: $nameInput)
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("Icon (optional SF Symbol)", text: $iconInput)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button {
                                guard !nameInput.isEmpty else { return }
                                addProfile(name: nameInput, icon: iconInput.isEmpty ? "person.crop.circle" : iconInput)
                                
                                nameInput = ""
                                iconInput = ""
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
                        }
                        .padding(.vertical, 6)
                    }
                }
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

                
            case .enterURL(let privateMode):
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
        }
        .listStyle(.inset)
        .navigationTitle(screen == .commands ? "Commands" : "Select Profile")
        .searchable(
            text: $searchText,
            prompt: screen == .commands ? "Search commands" : screen == .profiles ? "Search profiles" : "Cannot search"
        )
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
    
    @ViewBuilder
    private func row(
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
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
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
    
    private func addProfile(name: String, icon: String) {
        var current = (try? JSONDecoder().decode(
            [Profile].self,
            from: Data(profilesJSON.utf8)
        )) ?? []
        
        current.append(Profile(name: name, icon: icon))
        
        profilesJSON = String(
            data: try! JSONEncoder().encode(current),
            encoding: .utf8
        )!
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
        
        let store = WKWebsiteDataStore(forIdentifier: profile.id)
        
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) {
                print("Profile data wiped")
            }
        }
    }}
