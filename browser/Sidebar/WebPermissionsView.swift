import SwiftUI
import WebKit

private enum WebsitePermissionCategory: String, CaseIterable, Identifiable {
    case notifications, contentBlockers, autoplay, zoom, camera, microphone, location, popups, javascript

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications: "Notifications"
        case .contentBlockers: "Content Blockers"
        case .autoplay: "Auto-Play"
        case .zoom: "Page Zoom"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .location: "Location"
        case .popups: "Pop-up Windows"
        case .javascript: "JavaScript"
        }
    }

    var icon: String {
        switch self {
        case .notifications: "bell.badge"
        case .contentBlockers: "checkmark.shield"
        case .autoplay: "play.rectangle"
        case .zoom: "plus.magnifyingglass"
        case .camera: "video"
        case .microphone: "mic"
        case .location: "location"
        case .popups: "macwindow.on.rectangle"
        case .javascript: "curlybraces.square"
        }
    }

    var key: String {
        switch self {
        case .contentBlockers: "contentblockers"
        case .popups: "popups"
        case .zoom: "zoom"
        default: rawValue
        }
    }

    var isMedia: Bool { [.notifications, .camera, .microphone, .location].contains(self) }
}

struct WebPermissionsView: View {
    let profile: String
    @ObservedObject private var permissions = SitePermissionStore.shared
    @State private var dataHosts: Set<String> = []
    @State private var searchText = ""
    @State private var selectedCategory: WebsitePermissionCategory = .notifications
    @State private var selectedHosts: Set<String> = []

    init(profile: String = "") {
        self.profile = profile
    }

    private var hosts: [String] {
        let all = dataHosts.union(permissions.permissions.keys)
        return all.filter { searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var configuredHosts: [String] {
        hosts.filter { permissions.permissions[$0]?[selectedCategory.key] != nil }
    }

    private var otherHosts: [String] {
        hosts.filter { permissions.permissions[$0]?[selectedCategory.key] == nil }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Permissions")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(WebsitePermissionCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                                selectedHosts.removeAll()
                            } label: {
                                Label(category.title, systemImage: category.icon)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(selectedCategory == category ? Color.accentColor.opacity(0.16) : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedCategory == category ? Color.accentColor : Color.primary)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(width: 190)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(selectedCategory.title)
                    .font(.title3.weight(.semibold))
                Text("Choose how websites can use \(selectedCategory.title.lowercased()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Search websites", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if hosts.isEmpty {
                    ContentUnavailableView(searchText.isEmpty ? "No Websites Yet" : "No Matching Websites",
                                           systemImage: "globe",
                                           description: Text(searchText.isEmpty ? "Sites you visit or configure will appear here." : "Try another search."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedHosts) {
                        if !configuredHosts.isEmpty {
                            Section("Configured Websites") {
                                ForEach(configuredHosts, id: \.self) { host in
                                    siteRow(host)
                                }
                            }
                        }
                        if !otherHosts.isEmpty {
                            Section("Other Websites") {
                                ForEach(otherHosts, id: \.self) { host in
                                    siteRow(host)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
                HStack {
                    Button("Remove Setting") {
                        for host in selectedHosts {
                            permissions.removeSetting(for: host, type: selectedCategory.key)
                        }
                        selectedHosts.removeAll()
                    }
                    .disabled(selectedHosts.isEmpty)
                    Spacer()
                    Text("Other websites use the default setting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: profile) { await loadHosts() }
    }

    private func siteRow(_ host: String) -> some View {
        HStack {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)
            Text(host)
                .lineLimit(1)
            Spacer()
            permissionPicker(for: host)
                .labelsHidden()
                .frame(width: 115)
        }
        .tag(host)
    }

    @ViewBuilder
    private func permissionPicker(for host: String) -> some View {
        if selectedCategory.isMedia {
            Picker(selectedCategory.title, selection: Binding(
                get: { permissions.mediaPermission(for: host, type: selectedCategory.key) },
                set: { permissions.setMediaPermission(for: host, type: selectedCategory.key, state: $0) }
            )) {
                ForEach(PermissionState.allCases, id: \.self) { state in
                    Text(state.rawValue).tag(state)
                }
            }
        } else if selectedCategory == .contentBlockers {
            Picker(selectedCategory.title, selection: Binding(
                get: { permissions.toggleState(for: host, type: selectedCategory.key, defaultState: .enabled) },
                set: { permissions.setToggleState(for: host, type: selectedCategory.key, state: $0) }
            )) {
                ForEach(ToggleState.allCases, id: \.self) { state in
                    Text(state.rawValue).tag(state)
                }
            }
        } else if selectedCategory == .zoom {
            Picker(selectedCategory.title, selection: Binding(
                get: { permissions.zoomLevel(for: host) },
                set: { permissions.setZoomLevel(for: host, value: $0) }
            )) {
                ForEach([50, 75, 85, 100, 115, 125, 150, 175, 200], id: \.self) { value in
                    Text("\(value)%").tag(value)
                }
            }
        } else {
            Picker(selectedCategory.title, selection: Binding(
                get: { permissions.setting(for: host, type: selectedCategory.key, defaultState: .allow) },
                set: { permissions.setSetting(for: host, type: selectedCategory.key, state: $0) }
            )) {
                ForEach(SettingState.allCases, id: \.self) { state in
                    Text(state.rawValue).tag(state)
                }
            }
        }
    }

    @MainActor
    private func loadHosts() async {
        let dataStore: WKWebsiteDataStore
        if let identifier = UUID(uuidString: profile) {
            dataStore = WKWebsiteDataStore(forIdentifier: identifier)
        } else {
            dataStore = .default()
        }
        let records = await dataStore.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        dataHosts = Set(records.map(\.displayName).filter { !$0.isEmpty })
    }
}
