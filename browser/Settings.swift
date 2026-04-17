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
}

struct SettingRow: View {
    let setting: Setting

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            
            if setting.type != "header" {
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
    name:"Browsing",
    type:"header",
    appStorageKey: ""
    ),
    Setting(
            name: "Homepage",
            type: "text",
            appStorageKey: "homepage",
        ),
    Setting(
            name: "Search Engine",
            type: "text",
            appStorageKey: "searchEngine",
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
            name: "AI Temperature",
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
            name: "AI Instructions",
            type: "text",
            appStorageKey: "instructions",
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
            name: "Bookmark Bar",
            type: "slider",
            appStorageKey: "bookmarkBar",
            sliderMax:2,
            sliderMin:0,
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
        // Initialize AppStorage with the Bool default value
        self._isEnabled = AppStorage(
            wrappedValue: setting.defaultValueBool ?? false,
            setting.appStorageKey,
            store: Config.sharedDefaults
        )
    }

    var body: some View {
        Toggle(isOn: $isEnabled) {
            // Optional: You can put setting.name here if you want it
            // inside the toggle row instead of the header above it
            Text("Enable \(setting.name)")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
    @EnvironmentObject var tabManager: TabManager
   
    @StateObject private var store = BookmarkStore()
    
    @AppStorage("sidebarWidth", store:Config.sharedDefaults)
    var sidebarWidth: Int = 300


    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Settings) { setting in
                        SettingRow(setting: setting)
                            .padding(.horizontal)
                    }
                }
            }.frame(width:CGFloat(sidebarWidth))
        }.padding(.vertical)
    }
}
