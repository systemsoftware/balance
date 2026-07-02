import SwiftUI
import WebKit

// MARK: - Category Definitions
struct CategoryDef: Equatable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    var description: String
}

let catBrowsing = CategoryDef(
    id: "browsing",
    name: "Browsing",
    icon: "globe",
    color: .blue,
    description: "Manage core browsing behavior like search, homepage, and page handling."
)

let catSidebar = CategoryDef(
    id: "sidebar",
    name: "Sidebar",
    icon: "sidebar.left",
    color: .indigo,
    description: "Customize sidebar visibility and width."
)

let catAI = CategoryDef(
    id: "ai",
    name: "AI",
    icon: "sparkles",
    color: .purple,
    description: "Configures AI features including model behavior, prompts, and response settings."
)

let catToolbar = CategoryDef(
    id: "toolbar",
    name: "Toolbar",
    icon: "menubar.rectangle",
    color: .orange,
    description: "Manage which controls appear in the toolbar."
)

let catPalette = CategoryDef(
    id: "palette",
    name: "Palette",
    icon: "magnifyingglass",
    color: .teal,
    description: "Manage what appears in the command palette."
)

let catBookmarks = CategoryDef(
    id: "bookmarks",
    name: "Bookmarks",
    icon: "bookmark",
    color: .yellow,
    description: "Manage bookmark display and organization."
)

let catPrivacy = CategoryDef(
    id: "privacy",
    name: "Privacy",
    icon: "lock.shield",
    color: .green,
    description: "Manage data retention, tracking preferences, and local browsing privacy options."
)

let catAdvanced = CategoryDef(
    id: "advanced",
    name: "Advanced",
    icon: "wrench.and.screwdriver",
    color: .red,
    description: "Developer and system-level settings for deeper customization and debugging tools."
)

let catProfiles = CategoryDef(
    id:"profiles",
    name:"Profiles",
    icon:"person",
    color: .pink,
    description: "Manage and switch between different browsing profiles."
)

let catLearnMore = CategoryDef(
    id:"learnmore",
    name:"Learn More",
    icon:"info.circle",
    color: .white,
    description: "Learn Balance's features and how to get started."
)
let categoryDefs: [CategoryDef] = [
    catBrowsing, catSidebar, catAI, catToolbar, catPalette, catBookmarks, catProfiles, catPrivacy, catAdvanced, catLearnMore
]

struct Setting: Identifiable {
    var id: String { appStorageKey.isEmpty ? "header-\(name)" : appStorageKey }
    var name: String
    var icon: String = "gearshape"
    var category: CategoryDef
    var type: String // "slider", "toggle", "text"
    var appStorageKey: String
    var sliderMax: Int?
    var sliderMin: Int?
    var defaultValueInt: Int?
    var defaultValueString: String?
    var defaultValueBool: Bool?
    var defaultValueDouble: Double?
    var dropdownOptions: DropdownOptionsSource?
    var buttonText: String?
    var action: (() -> Void)?
}

enum DropdownOptionsSource {
    case staticOptions([Int: String])
    case staticTaggedOptions([String: String])
}


// MARK: SETTINGS DATA
var Settings: [Setting] = [
    Setting(
        name: "Browsing History",
        icon: "clock",
        category: catPrivacy,
        type: "toggle",
        appStorageKey: "recordHistory",
        defaultValueBool: true
    ),
    Setting(
        name: "Search Engine",
        icon: "magnifyingglass",
        category: catBrowsing,
        type: "dropdownString",
        appStorageKey: "searchURL",
        defaultValueString: "https://google.com/search?q=",
        dropdownOptions: .staticTaggedOptions([
            "https://google.com/search?q=": "Google",
            "https://www.bing.com/search?q=": "Bing",
            "https://duckduckgo.com/?q=": "DuckDuckGo",
            "https://www.perplexity.ai/search/new?q=": "Perplexity",
            "https://en.wikipedia.org/wiki/": "Wikipedia",
            "https://search.yahoo.com/search?p=": "Yahoo"
        ])
    ),
    Setting(
        name: "Autocomplete Engine",
        icon: "text.cursor",
        category: catBrowsing,
        type: "dropdownString",
        appStorageKey: "autofillEngine",
        defaultValueString: "https://ac.duckduckgo.com/ac/?&type=list&q=",
        dropdownOptions: .staticTaggedOptions([
            "https://ac.duckduckgo.com/ac/?&type=list&q=": "DuckDuckGo",
            "https://suggestqueries.google.com/complete/search?client=firefox&hl=en&q=": "Google"
        ])
    ),
    Setting(
        name: "Homepage",
        icon: "house",
        category: catBrowsing,
        type: "text",
        appStorageKey: "homepage",
        defaultValueString: "default-home"
    ),
    Setting(
        name: "Enable",
        icon: "sidebar.right",
        category: catSidebar,
        type: "toggle",
        appStorageKey: "showSidebar",
        defaultValueBool: true
    ),
    Setting(
        name: "Width",
        icon: "arrow.left.and.right",
        category: catSidebar,
        type: "slider",
        appStorageKey: "sidebarWidth",
        sliderMax: 600,
        sliderMin: 100,
        defaultValueInt: 345
    ),
    Setting(
        name: "Temperature",
        icon: "thermometer",
        category: catAI,
        type: "doubleSlider",
        appStorageKey: "temp",
        sliderMax: 1,
        sliderMin: 0,
        defaultValueDouble: 0.7
    ),
    Setting(
        name: "Max Tokens",
        icon: "number",
        category: catAI,
        type: "slider",
        appStorageKey: "maxTokens",
        sliderMax: 1000,
        sliderMin: 10,
        defaultValueInt: 1000
    ),
    Setting(
        name: "Page Character Cutoff",
        icon: "scissors",
        category: catAI,
        type: "slider",
        appStorageKey: "pageCutoff",
        sliderMax: 15000,
        sliderMin: 0,
        defaultValueInt: 12000
    ),
    Setting(
        name: "Instructions",
        icon: "text.quote",
        category: catAI,
        type: "text",
        appStorageKey: "instructions"
    ),
    Setting(
        name: "Bookmark Bar",
        icon: "bookmark",
        category: catBookmarks,
        type: "dropdown",
        appStorageKey: "bookmarkBar",
        defaultValueInt: 0,
        dropdownOptions: .staticOptions(Dictionary(uniqueKeysWithValues: BookmarkBarMode.allCases.map { ($0.rawValue, $0.name) }))
    ),
    Setting(
        name: "Clear Browsing History On Close",
        icon: "clock.badge.xmark",
        category: catPrivacy,
        type: "toggle",
        appStorageKey: "clearHistoryOnClose",
        defaultValueBool: false
    ),
    Setting(
        name: "Clear Download History On Close",
        icon: "arrow.down.circle.badge.xmark",
        category: catPrivacy,
        type: "toggle",
        appStorageKey: "clearDownloadHistoryOnClose",
        defaultValueBool: true
    ),
    Setting(
        name: "Tabs",
        icon: "square.on.square",
        category: catPalette,
        type: "toggle",
        appStorageKey: "paletteShowTabs",
        defaultValueBool: true
    ),
    Setting(
        name: "Bookmarks",
        icon: "bookmark",
        category: catPalette,
        type: "toggle",
        appStorageKey: "paletteShowBookmarks",
        defaultValueBool: true
    ),
    Setting(
        name: "Search",
        icon: "magnifyingglass.circle",
        category: catPalette,
        type: "toggle",
        appStorageKey: "paletteShowSearch",
        defaultValueBool: true
    ),
    Setting(
        name: "Commands",
        icon: "terminal",
        category: catPalette,
        type: "toggle",
        appStorageKey: "paletteShowCommands",
        defaultValueBool: true
    ),
    Setting(
        name: "History",
        icon: "clock.arrow.circlepath",
        category: catPalette,
        type: "toggle",
        appStorageKey: "paletteShowHistory",
        defaultValueBool: true
    ),
    Setting(
        name: "Clock",
        icon: "clock",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showClockInToolbar",
        defaultValueBool: false
    ),
    Setting(
        name: "Share Button",
        icon: "square.and.arrow.up",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showShareInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "Reload Button",
        icon: "arrow.clockwise",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showReloadInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "Address Bar",
        icon: "link",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showAddrBarInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "Navigation Buttons",
        icon: "chevron.left.chevron.right",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showNavInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "Search Button",
        icon: "magnifyingglass",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showSearchButtonInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "Autocomplete Button",
        icon: "text.cursor",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showAutocompleteInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "Extensions Button",
        icon: "puzzlepiece",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showExtInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "More Menu",
        icon: "ellipsis",
        category: catToolbar,
        type: "toggle",
        appStorageKey: "showMoreInToolbar",
        defaultValueBool: true
    ),
    Setting(
        name: "User Agent",
        icon: "person.crop.rectangle",
        category: catAdvanced,
        type: "text",
        appStorageKey: "userAgent"
    ),
    Setting(
        name: "Preserve On Close",
        icon: "archivebox",
        category: catAdvanced,
        type: "toggle",
        appStorageKey: "preserveOnClose",
        defaultValueBool: true
    ),
    Setting(
        name: "Use PDFKit",
        icon: "doc.richtext",
        category: catAdvanced,
        type: "toggle",
        appStorageKey: "usePDFKit",
        defaultValueBool: true
    ),
    Setting(
        name: "Show Tabs in Dock",
        icon: "dock.arrow.down.rectangle",
        category: catAdvanced,
        type: "toggle",
        appStorageKey: "showTabsInDockMenu",
        defaultValueBool: false
    ),
    Setting(
        name: "Open App Data",
        icon: "folder",
        category: catAdvanced,
        type: "button",
        appStorageKey: "",
        buttonText: "Open",
        action: {
            if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                NSWorkspace.shared.open(url)
            }
        }
    ),
    Setting(
        name: "Theme",
        icon: "paintbrush",
        category: catAdvanced,
        type: "dropdownString",
        appStorageKey: "themePreference",
        defaultValueString: "system",
        dropdownOptions: .staticTaggedOptions([
            "system": "System",
            "light": "Light",
            "dark": "Dark"
        ])
    ),
    Setting(
        name: "Default Page Zoom (%)",
        icon: "magnifyingglass.circle",
        category: catBrowsing,
        type: "slider",
        appStorageKey: "defaultPageZoom",
        sliderMax: 200,
        sliderMin: 50,
        defaultValueInt: 100
    ),
    Setting(
        name: "HTTPS Only",
        icon: "lock",
        category: catPrivacy,
        type: "toggle",
        appStorageKey: "httpsOnly",
        defaultValueBool: false
    ),
    Setting(
        name: "Do Not Track Header",
        icon: "hand.raised",
        category: catPrivacy,
        type: "toggle",
        appStorageKey: "doNotTrack",
        defaultValueBool: false
    ),
    Setting(
        name: "Open Links in Background",
        icon: "arrow.up.right.square",
        category: catBrowsing,
        type: "toggle",
        appStorageKey: "openLinksInBackground",
        defaultValueBool: false
    ),
    
    Setting(
        name: "Homepage",
        icon: "house",
        category: catLearnMore,
        type: "button",
        appStorageKey: "",
        buttonText: "Open",
        action: {
            createNewTab(with:URL(string:"https://systemsoftware.github.io/about/balance"))
        }
    ),
    Setting(
        name: "README",
        icon: "doc.text",
        category: catLearnMore,
        type: "button",
        appStorageKey: "",
        buttonText: "Open",
        action: {
            createNewTab(with:URL(string:"https://github.com/systemsoftware/balance/blob/main/README.md"))
        }
    ),
    Setting(
        name: "FEATURES.md",
        icon: "doc.text.fill",
        category: catLearnMore,
        type: "button",
        appStorageKey: "",
        buttonText: "Open",
        action: {
            createNewTab(with:URL(string:"https://github.com/systemsoftware/balance/blob/main/FEATURES.md"))
        }
    ),
    Setting(
        name: "GitHub Repo",
        icon: "curlybraces",
        category: catLearnMore,
        type: "button",
        appStorageKey: "",
        buttonText: "Open",
        action: {
            createNewTab(with:URL(string:"https://github.com/systemsoftware/balance"))
        }
    )
]

// MARK: - Header (legacy, kept for any external usage)
struct Header: View {
    var text = ""
    var body: some View {
        Text(text)
            .font(.title2)
            .padding(0)
    }
}

// MARK: - Slider Component (Int)
struct SliderIntRow: View {
    let setting: Setting
    @AppStorage var value: Int

    init(setting: Setting) {
        self.setting = setting
        self._value = AppStorage(wrappedValue: setting.defaultValueInt ?? 0, setting.appStorageKey, store: Config.sharedDefaults)
    }

    var body: some View {
        HStack {
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: Double(setting.sliderMin ?? 0)...Double(setting.sliderMax ?? 100))
            Text("\(value)").monospacedDigit().frame(width: 40)
        }
    }
}

// MARK: - Dropdown Component (Enum/Int)
struct DropdownRow: View {
    let setting: Setting
    @AppStorage var selectedValue: Int

    init(setting: Setting) {
        self.setting = setting
        let defaultVal = setting.defaultValueInt ?? 0
        self._selectedValue = AppStorage(
            wrappedValue: defaultVal,
            setting.appStorageKey,
            store: Config.sharedDefaults
        )
    }

    var options: [String: String] {
        switch setting.dropdownOptions {
        case .staticOptions(let options):
            return Dictionary(uniqueKeysWithValues: options.map { (String($0.key), $0.value) })
        case .none:
            return [:]
        case .staticTaggedOptions(let options):
            return options
        }
    }

    var body: some View {
        Picker(setting.name, selection: $selectedValue) {
            ForEach(options.keys.sorted(), id: \.self) { key in
                if let keyInt = Int(key) {
                    Text(options[key]!).tag(keyInt)
                } else {
                    Text(options[key]!).tag(key)
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }
}

// MARK: - Dropdown Component (String)
struct DropdownStringRow: View {
    let setting: Setting
    @AppStorage var selectedValue: String

    init(setting: Setting) {
        self.setting = setting
        let defaultVal = setting.defaultValueString ?? ""
        self._selectedValue = AppStorage(
            wrappedValue: defaultVal,
            setting.appStorageKey,
            store: Config.sharedDefaults
        )
    }

    var options: [String: String] {
        switch setting.dropdownOptions {
        case .staticTaggedOptions(let options):
            return options
        default:
            return [:]
        }
    }

    var body: some View {
        Picker(setting.name, selection: $selectedValue) {
            ForEach(options.keys.sorted(), id: \.self) { key in
                Text(options[key]!).tag(key)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }
}

// MARK: - Slider Component (Double)
struct SliderDoubleRow: View {
    let setting: Setting
    @AppStorage var value: Double

    init(setting: Setting) {
        self.setting = setting
        self._value = AppStorage(
            wrappedValue: setting.defaultValueDouble ?? 0.0,
            setting.appStorageKey,
            store: Config.sharedDefaults
        )
    }

    var body: some View {
        HStack {
            Slider(value: $value, in: Double(setting.sliderMin ?? 0)...Double(setting.sliderMax ?? 1))
            Text(String(format: "%.2f", value))
                .monospacedDigit()
                .frame(width: 45)
        }
    }
}

// MARK: - Toggle Component (Bool)
struct ToggleRow: View {
    let setting: Setting
    @AppStorage var isEnabled: Bool

    init(setting: Setting) {
        self.setting = setting
        self._isEnabled = AppStorage(
            wrappedValue: setting.defaultValueBool ?? false,
            setting.appStorageKey,
            store: Config.sharedDefaults
        )
    }

    var body: some View {
        Toggle("", isOn: $isEnabled)
            .toggleStyle(.switch)
            .labelsHidden()
    }
}

// MARK: - TextField Component (String)
struct TextFieldRow: View {
    let setting: Setting
    @AppStorage var textValue: String

    init(setting: Setting) {
        self.setting = setting
        self._textValue = AppStorage(wrappedValue: setting.defaultValueString ?? "", setting.appStorageKey, store: Config.sharedDefaults)
    }

    var body: some View {
        TextField("Enter \(setting.name)", text: $textValue)
            .textFieldStyle(.roundedBorder)
    }
}

// MARK: - Button Component
struct ButtonRow: View {
    let setting: Setting

    init(setting: Setting) {
        self.setting = setting
    }

    var body: some View {
        Button {
            setting.action?()
        } label: {
            Text(setting.buttonText ?? setting.name)
        }
    }
}

// MARK: - SettingRow (legacy wrapper).
struct SettingRow: View {
    let setting: Setting
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if setting.type != "header" && setting.type != "dropdown" && setting.type != "dropdownString" && setting.type != "toggle" {
                Text(setting.name).font(.headline)
            }
            switch setting.type {
            case "slider":       SliderIntRow(setting: setting)
            case "doubleSlider": SliderDoubleRow(setting: setting)
            case "toggle":       ToggleRow(setting: setting)
            case "text":         TextFieldRow(setting: setting)
            case "header":       Header(text: setting.name)
            case "dropdown":     DropdownRow(setting: setting)
            case "dropdownString": DropdownStringRow(setting: setting)
            case "button":       ButtonRow(setting: setting)
            default:             EmptyView()
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Inline Setting Control (right-aligned)
struct InlineSettingControl: View {
    let setting: Setting

    var body: some View {
        switch setting.type {
        case "toggle":
            ToggleRow(setting: setting)
        case "dropdown":
            DropdownRow(setting: setting)
        case "dropdownString":
            DropdownStringRow(setting: setting)
        case "button":
            ButtonRow(setting: setting)
        default:
            EmptyView()
        }
    }
}

// MARK: - Block Setting Control (full-width beneath label)
struct BlockSettingControl: View {
    let setting: Setting

    var body: some View {
        switch setting.type {
        case "slider":
            SliderIntRow(setting: setting)
        case "doubleSlider":
            SliderDoubleRow(setting: setting)
        case "text":
            TextFieldRow(setting: setting)
        default:
            EmptyView()
        }
    }
}

private func isInlineSetting(_ type: String) -> Bool {
    ["toggle", "dropdown", "dropdownString", "button"].contains(type)
}

// MARK: - Settings Card Row
struct SettingsCardRow: View {
    let setting: Setting
    let icon: String
    let accentColor: Color

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Text(setting.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                if isInlineSetting(setting.type) {
                    InlineSettingControl(setting: setting)
                        .controlSize(.small)
                }
            }

            if !isInlineSetting(setting.type) {
                BlockSettingControl(setting: setting)
                    .padding(.leading, 38)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered
                      ? Color(NSColor.controlBackgroundColor).opacity(0.8)
                      : Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}



// MARK: - Category Chip (sidebar compact mode)
struct CategoryChip: View {
    let def: CategoryDef
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: def.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(def.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? def.color.opacity(0.2) : Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? def.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? def.color : .secondary)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Sidebar Navigation Item (standalone)
struct SidebarNavItem: View {
    let def: CategoryDef
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? def.color.opacity(0.2) : Color.clear)
                        .frame(width: 30, height: 30)
                    Image(systemName: def.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? def.color : .secondary)
                }
                Text(def.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? def.color.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Settings Section Content
struct SettingsSectionContent: View {
    let def: CategoryDef
    let profiles: [Profile]
    @Binding var defaultProfile: String
    var activeProfile: String?

    private var settingsForCategory: [Setting] {
        Settings.filter { $0.category.id == def.id }
    }

    @State var st = ""
    
    var isStandalone = false
    
    @State var emptyStringBinding = ""
    @State var falseBinding = false
    @State var newProfile = false
    
    @State var showNewBookmark = false
    
    @State var learnMoreState = "https://systemsoftware.github.io/balance"
    
    @State private var lmpage = WebPage()
    
    private func loadInitialURL() {
        if !learnMoreState.isEmpty, let url = URL(string: learnMoreState) {
            lmpage.load(URLRequest(url: url))
        }
    }

    private func updateURL(_ urlString: String) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }
        lmpage.load(URLRequest(url: url))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if def.id == "profiles" && !profiles.isEmpty {
                    profilePickerRow
            }
            
            ForEach(settingsForCategory) { setting in
                SettingsCardRow(
                    setting: setting,
                    icon: setting.icon,
                    accentColor: def.color
                )
            }
            
            if def.id == "bookmarks" && isStandalone {
                SettingsCardRow(
                    setting: Setting(
                        name:"New Bookmark",
                        category: catBookmarks,
                        type:"button",
                        appStorageKey:"",
                        buttonText:"New",
                        action: {
                            showNewBookmark = true
                        }
                    ),
                    icon: "plus",
                    accentColor: def.color
                )
                SettingsCardRow(
                    setting: Setting(
                        name:"Manage",
                        category: catBookmarks,
                        type:"header",
                        appStorageKey:"",
                    ),
                    icon: "gearshape",
                    accentColor: def.color
                )
                BookmarksView(showAddBookmark:$showNewBookmark,isSettings:true)
                    .padding(.top, -5)
                    .padding(.leading)
            }
            
            if def.id == "profiles" {
                SettingsCardRow(
                    setting: Setting(
                        name:"New Profile",
                        category: catProfiles,
                        type:"button",
                        appStorageKey:"",
                        action: {
                            newProfile.toggle()
                        }
                    ),
                    icon: "plus",
                    accentColor: def.color
                )
                
                SettingsCardRow(
                    setting: Setting(
                        name:"Manage",
                        category: catProfiles,
                        type:"header",
                        appStorageKey:"",
                    ),
                    icon: "gearshape",
                    accentColor: def.color
                )
                .padding(0)
                
                ProfileView(searchText: $emptyStringBinding, hideProfileList: $falseBinding, showNewProfile: $newProfile, showHeader:false)
                    .padding(.horizontal)
                    .padding(.leading)

            }
            
            if def.id == "palette" && isStandalone {
                    SettingsCardRow(
                        setting: Setting(
                            name:"Reorder",
                            category: catPalette,
                            type:"header",
                            appStorageKey:"",
                        ),
                        icon: "gearshape",
                        accentColor: def.color
                    )
                    .padding(0)
                    .zIndex(5)
                    CommandsView(searchText:$st, showData: false, searchQuery: $st)
                        .padding(.vertical, -20)
                        .padding(.leading)
                        .background(Color.clear)
            }

            if def.id == "advanced" && !defaultProfile.isEmpty {
                clearProfileCacheButton
            }

            if def.id == "advanced" {
                clearCacheButton
            }
        }
    }

    private var profilePickerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(def.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "person.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(def.color)
            }
            Text("Default Profile")
                .font(.system(size: 13, weight: .medium, design: .rounded))
            Spacer()
            Picker("", selection: $defaultProfile) {
                Text("None").tag("")
                ForEach(profiles) { profile in
                    Text(profile.name).tag(profile.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
    }

    private var clearProfileCacheButton: some View {
        Button {
            let targetProfile = (activeProfile?.isEmpty == false) ? activeProfile! : defaultProfile
            guard let uuid = UUID(uuidString: targetProfile) else { return }
            let store = WKWebsiteDataStore(forIdentifier: uuid)
            store.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date(timeIntervalSince1970: 0),
                completionHandler: {
                    windowAlert(message: "Removed data for active profile")
                }
            )
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                }
                Text("Clear Profile Cache")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }

    private var clearCacheButton: some View {
        Button {
            WKWebsiteDataStore.default().removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date(timeIntervalSince1970: 0),
                completionHandler: {
                    windowAlert(message: "Default cache cleared.")
                }
            )
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                }
                Text("Clear Default Cache")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main SettingsView
struct SettingsView: View {
    var isStandalone: Bool = false
    var activeProfile: String? = nil

    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345

    @AppStorage("defaultProfile", store: Config.sharedDefaults)
    var defaultProfile = ""

    @AppStorage("profiles", store: Config.sharedDefaults)
    private var profilesJSON = "[]"

    @State private var selectedCategoryID: String = categoryDefs[0].id
    @State private var searchText: String = ""

    private var profiles: [Profile] {
        (try? JSONDecoder().decode([Profile].self, from: Data(profilesJSON.utf8))) ?? []
    }

    private var selectedCategory: CategoryDef {
        categoryDefs.first { $0.id == selectedCategoryID } ?? categoryDefs[0]
    }

    private var displayCategories: [CategoryDef] {
        if isStandalone {
            return categoryDefs
        } else {
            return categoryDefs.filter { $0.id != "sidebar" }
        }
    }

    private var searchResults: [Setting] {
        if searchText.isEmpty { return [] }
        return Settings.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        if isStandalone {
            standaloneLayout
        } else {
            sidebarLayout
        }
    }

    // MARK: Standalone (two-column)
    private var standaloneLayout: some View {
        HStack(spacing: 0) {
            // Left nav panel
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ForEach(displayCategories, id: \.id) { def in
                    SidebarNavItem(
                        def: def,
                        isSelected: selectedCategoryID == def.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategoryID = def.id
                            searchText = ""
                        }
                    }
                    .padding(.horizontal, 6)
                }

                Spacer()
            }
            .frame(width: 170)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

            Divider()

            // Right content panel
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                    TextField("Search settings…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .rounded))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                ScrollView {
                    if !searchText.isEmpty {
                        searchResultsPanel(accentColor: .blue)
                    } else {
                        categoryPanel(def: selectedCategory)
                    }
                }
            }
        }
        .frame(minWidth: 580, minHeight: 450)
    }

    // MARK: Sidebar (single-column)
    private var sidebarLayout: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Settings")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            if searchText.isEmpty {
                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(displayCategories, id: \.id) { def in
                            CategoryChip(
                                def: def,
                                isSelected: selectedCategoryID == def.id
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedCategoryID = def.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }

                Divider()
                    .padding(.bottom, 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if !searchText.isEmpty {
                        searchResultsPanel(accentColor: .blue)
                    } else {
                        // Category title
                        HStack(spacing: 6) {
                            Image(systemName: selectedCategory.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selectedCategory.color)
                            Text(selectedCategory.name)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                        SettingsSectionContent(
                            def: selectedCategory,
                            profiles: profiles,
                            defaultProfile: $defaultProfile,
                            activeProfile: activeProfile
                        )
                        .padding(.horizontal, 8)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .padding(.bottom, 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedCategoryID)
            }
        }
        .frame(maxWidth: CGFloat(sidebarWidth))
    }

    // MARK: - Search results
    @ViewBuilder
    private func searchResultsPanel(accentColor: Color) -> some View {
        let results = searchResults
        VStack(alignment: .leading, spacing: 4) {
            if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(results) { setting in
                    SettingsCardRow(
                        setting: setting,
                        icon: setting.icon,
                        accentColor: categoryColor(for: setting)
                    )
                }
            }
        }
        .padding(.horizontal, isStandalone ? 16 : 8)
        .padding(.top, 8)
    }

    // MARK: - Category panel (standalone)
    @ViewBuilder
    private func categoryPanel(def: CategoryDef) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(def.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: def.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(def.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(def.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    // • \(Settings.filter { $0.category.id == def.id }.count) settings
                    Text("\(def.description)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)

            SettingsSectionContent(
                def: def,
                profiles: profiles,
                defaultProfile: $defaultProfile,
                activeProfile: activeProfile,
                isStandalone: isStandalone
            )
            .padding(.horizontal, 16)

            Spacer(minLength: 20)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: def.id)
    }

    private func categoryColor(for setting: Setting) -> Color {
        return setting.category.color
    }
}

// MARK: - windowAlert helper
func windowAlert(message: String) {
    let a = NSAlert()
    a.messageText = message
    a.runModal()
}
