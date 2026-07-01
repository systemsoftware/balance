import SwiftUI

struct Setting: Codable, Identifiable {
    var id = UUID()
    var name: String
    var type: String // "slider", "toggle", "text"
    var appStorageKey: String
    var sliderMax: Int?
    var sliderMin: Int?
    var defaultValueInt: Int?
    var defaultValueString: String?
    var defaultValueBool: Bool?
    var defaultValueDouble: Double?
    var dropdownOptions: DropdownOptionsSource?
}

enum DropdownOptionsSource: Codable {
    case staticOptions([Int: String])
    case staticTaggedOptions([String: String])
}

struct SettingRow: View {
    let setting: Setting

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            
            if setting.type != "header" && setting.type != "dropdown" && setting.type != "dropdownString" && setting.type != "toggle" {
                            Text(setting.name).font(.headline)
                        }
            
            switch setting.type {
            case "slider":
                SliderIntRow(setting: setting)
            case "doubleSlider":
                SliderDoubleRow(setting: setting)
            case "toggle":
                ToggleRow(setting: setting)
            case "text":
                TextFieldRow(setting: setting)
            case "header":
                Header(text: setting.name)
            case "dropdown":
                DropdownRow(setting: setting)
            case "dropdownString":
                DropdownStringRow(setting: setting)
            default:
                EmptyView()
            }
        }
        .padding(.vertical, 8)
    }
}


// MARK: SETTINGS
var Settings = [
    Setting(
            name: "Record History",
            type: "toggle",
            appStorageKey: "recordHistory",
            defaultValueBool: true
        ),
    Setting(
            name:"Search Engine",
            type:"dropdownString",
            appStorageKey:"searchURL",
            defaultValueString: "https://google.com/search?q=",
            dropdownOptions: .staticTaggedOptions([
                "https://google.com/search?q=": "Google",
                "https://www.bing.com/search?q=":"Bing",
                "https://duckduckgo.com/?q=":"DuckDuckGo",
                "https://www.perplexity.ai/search/new?q=": "Perplexity",
                "https://en.wikipedia.org/wiki/":"Wikipedia",
                "https://search.yahoo.com/search?p=":"Yahoo"
            ])
        ),
    Setting(
            name:"Autocomplete Engine",
            type:"dropdownString",
            appStorageKey:"autofillEngine",
            defaultValueString: "https://ac.duckduckgo.com/ac/?&type=list&q=",
            dropdownOptions: .staticTaggedOptions([
                "https://ac.duckduckgo.com/ac/?&type=list&q=": "DuckDuckGo",
                "https://suggestqueries.google.com/complete/search?client=firefox&hl=en&q=":"Google"
            ])
        ),
    Setting(
            name: "Homepage",
            type: "text",
            appStorageKey: "homepage",
            defaultValueString: "default-home"
        ),
    Setting(
        name:"Sidebar",
        type:"header",
        appStorageKey: ""
    ),
    Setting(
        name: "Width",
        type: "slider",
        appStorageKey: "sidebarWidth",
        sliderMax: 600,
        sliderMin: 100,
        defaultValueInt: 300
    ),
    Setting(
        name:"AI",
        type:"header",
        appStorageKey: ""
    ),
    Setting(
            name: "Temperature",
            type: "doubleSlider",
            appStorageKey: "temp",
            sliderMax: 1,
            sliderMin: 0,
            defaultValueDouble: 0.7
        ),
    Setting(
        name: "Max Tokens",
        type: "slider",
        appStorageKey: "maxTokens",
        sliderMax: 1000,
        sliderMin: 10,
        defaultValueInt: 1000
    ),
    Setting(
        name:"Page Character Cutoff",
        type:"slider",
        appStorageKey: "pageCutoff",
        sliderMax: 15000,
        sliderMin: 0,
        defaultValueInt: 12000
    ),
    Setting(
            name: "Instructions",
            type: "text",
            appStorageKey: "instructions",
        ),
    Setting(
        name:"Places from Tabs",
        type:"toggle",
        appStorageKey: "enableAIPlaces",
        defaultValueBool: true
    ),
    Setting(
        name:"Bookmark Bar",
        type:"header",
        appStorageKey: ""
    ),
    Setting(
            name: "Show on",
            type: "dropdown",
            appStorageKey: "bookmarkBar",
            defaultValueInt: 0,
            dropdownOptions:.staticOptions(Dictionary(uniqueKeysWithValues: BookmarkBarMode.allCases.map { ($0.rawValue, $0.name) })),
        ),
    Setting(
        name:"Delete On Close",
        type:"header",
        appStorageKey:""
    ),
    Setting(
        name:"Search History",
        type: "toggle",
        appStorageKey: "clearHistoryOnClose",
        defaultValueBool: false
    ),
    Setting(
        name:"Download History",
        type: "toggle",
        appStorageKey: "clearDownloadHistoryOnClose",
        defaultValueBool: true
    ),
    Setting(
        name:"Palette",
        type:"header",
        appStorageKey: ""
    ),
    Setting(
        name:"Tabs",
        type:"toggle",
        appStorageKey: "paletteShowTabs",
        defaultValueBool: true
    ),
    Setting(
        name:"Bookmarks",
        type:"toggle",
        appStorageKey: "paletteShowBookmarks",
        defaultValueBool: true
    ),
    Setting(
        name:"Search",
        type:"toggle",
        appStorageKey: "paletteShowSearch",
        defaultValueBool: true
    ),
    Setting(
        name:"Commands",
        type:"toggle",
        appStorageKey: "paletteShowCommands",
        defaultValueBool: true
    ),
    Setting(
        name:"History",
        type:"toggle",
        appStorageKey: "paletteShowHistory",
        defaultValueBool: true
    ),
    Setting(
        name:"Advanced",
        type:"header",
        appStorageKey: ""
    ),
    Setting(
            name: "User Agent",
            type: "text",
            appStorageKey: "userAgent",
        ),
    Setting(
        name:"Preserve On Close",
        type:"toggle",
        appStorageKey: "preserveOnClose",
        defaultValueBool: true
    ),
    Setting(
            name: "Use PDFKit",
            type: "toggle",
            appStorageKey: "usePDFKit",
            defaultValueBool: true
        ),
    Setting(
            name: "Show Tabs in Dock",
            type: "toggle",
            appStorageKey: "showTabsInDockMenu",
            defaultValueBool: false
        ),
]

// MARK: Header
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
            return Dictionary(
                uniqueKeysWithValues: options.map { (String($0.key), $0.value) }
            )

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
        Toggle(isOn: $isEnabled) {
            Text(setting.name)
                .font(.headline)
        }
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
struct SettingsView: View {
    @StateObject private var store = BookmarkStore()
    
    @AppStorage("sidebarWidth", store:Config.sharedDefaults)
    var sidebarWidth: Int = 300

    @AppStorage("defaultProfile", store:Config.sharedDefaults) var defaultProfile = ""
    
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

    var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                Text("Settings")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }.padding(.leading)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    
                    Header(text:"Browsing")
                        .padding(.horizontal)
                        .padding(.top)
                    Picker("Default Profile", selection: $defaultProfile) {
                        Text("None").tag("")

                        ForEach(profiles) { profile in
                            Text(profile.name)
                                .tag(profile.id.uuidString)
                        }
                    }
                    .padding(.horizontal)
                    
                    ForEach(Settings) { setting in
                        SettingRow(setting: setting)
                            .padding(.horizontal)
                    }
                }
            }.frame(width:CGFloat(sidebarWidth))
        }.padding(.vertical)
    }
}
