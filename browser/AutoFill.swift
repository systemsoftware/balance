import SwiftData
import SwiftUI
import Foundation

@Model
final class AutoFillItem {
    
    var id = UUID()
    var data: String
    var type: String // text, email, tel, etc
    var label: String?
    
    init(data: String, type: String = "", label: String? = nil) {
        self.data = data
        self.type = type
        self.label = label
    }
    
}

struct AutoFillStore {
    
    static let sharedContainer: ModelContainer = {
        let schema = Schema([AutoFillItem.self])
        do {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Balance", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(
                "AutoFill",
                schema: schema,
                url: directory.appendingPathComponent("AutoFill.store")
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("❌ Unable to open autofill store; using an in-memory store: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Unable to create the fallback autofill store: \(error)")
            }
        }
    }()
    
    static func add(data: String, type: String = "", label: String? = nil) {
        let context = sharedContainer.mainContext
        let item = AutoFillItem(data: data, type: type, label: label)
        context.insert(item)
        do {
            try context.save()
        } catch {
            print("❌ Unable to save autofill item: \(error)")
        }
    }
    
    static func remove(id: UUID) {
        let context = sharedContainer.mainContext
        let searchID = id
        let descriptor = FetchDescriptor<AutoFillItem>(
            predicate: #Predicate { $0.id == searchID }
        )
        do {
            if let item = try context.fetch(descriptor).first {
                context.delete(item)
                try context.save()
            }
        } catch {
            print("❌ Unable to delete autofill item: \(error)")
            context.rollback()
        }
    }
    
    static func GetForType(_ type: String) -> [AutoFillItem] {
        let context = sharedContainer.mainContext
        let searchType = type
        let descriptor = FetchDescriptor<AutoFillItem>(
            predicate: #Predicate { $0.type == searchType }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Unable to fetch autofill items for type '\(type)': \(error)")
            return []
        }
    }
    
    static func getAll() -> [AutoFillItem] {
        let context = sharedContainer.mainContext
        let descriptor = FetchDescriptor<AutoFillItem>()
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Unable to fetch all autofill items: \(error)")
            return []
        }
    }
    
    static func getMatching(type: String = "", label: String? = nil) -> [AutoFillItem] {
        let all = getAll()
        guard !all.isEmpty else { return [] }
        
        let cleanType = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanLabel = (label ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":*?"))
            .lowercased()
        
        func normalize(_ s: String) -> String {
            return s.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        
        let normLabel = normalize(cleanLabel)
        
        var scored: [(item: AutoFillItem, score: Int)] = []
        
        for item in all {
            var score = 0
            let itemType = item.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let itemRawLabel = (item.label ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ":*?"))
                .lowercased()
            let itemNormLabel = normalize(itemRawLabel)
            
            // 1. Direct Label Matching
            if !normLabel.isEmpty && !itemNormLabel.isEmpty {
                if itemNormLabel == normLabel {
                    score += 100
                } else if itemNormLabel.contains(normLabel) || normLabel.contains(itemNormLabel) {
                    score += 60
                }
            }
            
            // 2. Semantic Keyword Matching
            if !cleanLabel.isEmpty {
                // Email fields
                if (cleanLabel.contains("email") || cleanLabel.contains("mail")) &&
                   (itemType == "email" || itemRawLabel.contains("email") || item.data.contains("@")) {
                    score += 50
                }
                // Phone fields
                if (cleanLabel.contains("phone") || cleanLabel.contains("tel") || cleanLabel.contains("mobile")) &&
                   (itemType == "tel" || itemType == "phone" || itemRawLabel.contains("phone") || itemRawLabel.contains("tel")) {
                    score += 50
                }
                // Name fields
                if cleanLabel.contains("first") && (itemRawLabel.contains("first") || itemRawLabel.contains("fname") || itemRawLabel.contains("given")) {
                    score += 50
                } else if cleanLabel.contains("last") && (itemRawLabel.contains("last") || itemRawLabel.contains("lname") || itemRawLabel.contains("family") || itemRawLabel.contains("surname")) {
                    score += 50
                } else if cleanLabel.contains("name") && !cleanLabel.contains("user") && itemRawLabel.contains("name") && !itemRawLabel.contains("user") {
                    score += 30
                }
                // Address fields
                if (cleanLabel.contains("address") || cleanLabel.contains("street") || cleanLabel.contains("city") || cleanLabel.contains("zip")) &&
                   (itemRawLabel.contains("address") || itemRawLabel.contains("street") || itemRawLabel.contains("city") || itemRawLabel.contains("zip")) {
                    score += 50
                }
            }
            
            // 3. Type-only matching when input has no label
            if cleanLabel.isEmpty && !cleanType.isEmpty && cleanType != "text" {
                if itemType == cleanType {
                    score += 40
                } else if cleanType == "email" && (item.data.contains("@") || itemType == "email") {
                    score += 40
                } else if (cleanType == "tel" || cleanType == "phone") && (itemType == "tel" || itemType == "phone") {
                    score += 40
                }
            }
            
            if score > 0 {
                scored.append((item, score))
            }
        }
        
        guard !scored.isEmpty else { return [] }
        
        scored.sort { $0.score > $1.score }
        return scored.map { $0.item }
    }
}

enum EntryType: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case text = "text"
    case email = "email"
    case tel = "tel"
    case password = "password"
    case url = "url"
    case number = "number"
}

struct AutoFillSettingsView: View {
    @State private var items: [AutoFillItem] = []
    @State var showNewEntrySheet = false
    @State var newEntryData: String = ""
    @State var newEntryType: EntryType = .text
    @State var newEntryLabel: String = ""
    
    private func reloadItems() {
        items = AutoFillStore.getAll()
    }
    
    var body: some View {
        VStack {
            SettingsCardRow(
                setting: Setting(
                    name: "Add AutoFill Entry", category: catAutofill, type: "button", appStorageKey: "",
                    buttonText: "Add",
                    action: {
                        showNewEntrySheet = true
                    }
                ),
                icon: "plus",
                accentColor: catAutofill.color
            )
            
            SettingsCardRow(
                setting: Setting(
                    name:"Manage",
                    category: catBookmarks,
                    type:"header",
                    appStorageKey:"",
                ),
                icon: "gearshape",
                accentColor: catAutofill.color
            )
            .padding(.bottom, -15)
            
            List {
                if items.isEmpty {
                    Text("No saved AutoFill entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.data)
                                    .font(.body)
                                HStack {
                                    if let lbl = item.label, !lbl.isEmpty {
                                        Text(lbl)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.type)
                                        .font(.caption)
                                        .foregroundStyle(item.label == nil ? .secondary : .tertiary)
                                        .padding(.horizontal, 0)
                                }
                            }
                            Spacer()
                            Button(action: {
                                let idToDelete = item.id
                                AutoFillStore.remove(id: idToDelete)
                                withAnimation {
                                    items.removeAll { $0.id == idToDelete }
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
            .padding(.top, 0)
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            reloadItems()
        }
        .sheet(isPresented: $showNewEntrySheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add New AutoFill Entry")
                    .font(.headline)

                VStack(alignment: .leading) {
                    Text("Data")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("This is the actual data that will be filled into input fields on websites. For example, your email address or phone number.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. someone@example.com", text: $newEntryData)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Label (optional)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("This is a label for this entry. Balance will use this label to match this entry to the right input field on websites. If you leave this blank, Balance will try to match this entry based on its type.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                    TextField("e.g. First Name", text: $newEntryLabel)
                        .textFieldStyle(.roundedBorder)
                }

                
                VStack(alignment: .leading) {
                    Text("Type")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("This is the type of input field this entry is intended for. It helps the browser suggest the right data for the right fields.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $newEntryType) {
                        ForEach(EntryType.allCases) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showNewEntrySheet = false
                    }
                    Button("Save") {
                        AutoFillStore.add(data: newEntryData, type: newEntryType.rawValue, label: newEntryLabel.isEmpty ? nil : newEntryLabel)
                        newEntryData = ""
                        newEntryLabel = ""
                        newEntryType = .text
                        showNewEntrySheet = false
                        reloadItems()
                    }
                    .disabled(newEntryData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
    }
}
