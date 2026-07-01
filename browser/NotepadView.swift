import SwiftUI

enum NoteScope: String, CaseIterable, Identifiable {
    case global = "Global"
    case currentTab = "This Tab"
    case ephemeral = "Ephemeral"
    
    var id: String { self.rawValue }
}

struct NoteView: View {
    @AppStorage("notepad", store: Config.sharedDefaults) var notepad: String = ""
    
    @State var tabNote = ""
    var tabID: String = ""

    @State var noteScope: NoteScope = .global
    
    var body: some View {
        VStack{
            HStack {
                Text("Notepad")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Clear") {
                    switch noteScope {
                    case .global:
                        notepad = ""
                    case .currentTab:
                        Config.sharedDefaults?.set("", forKey: "note_\(tabID)")
                    case .ephemeral:
                        tabNote = ""
                    }
                }
                
                Picker("Scope", selection: $noteScope) {
                    ForEach(NoteScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }.padding()
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            
            noteEditor
                .scrollContentBackground(.hidden)
                .padding()
        }
    }
    
    @ViewBuilder
    var noteEditor: some View {
        switch noteScope {
        case .global:
            TextEditor(text: $notepad)
        case .currentTab:
            if tabID.isEmpty {
                TextEditor(text: .constant("No tab ID"))
            } else {
                TabNoteEditor(tabID: tabID)
            }
        case .ephemeral:
            TextEditor(text: $tabNote)
        }
    }
}

struct TabNoteEditor: View {
    var tabID: String
    @AppStorage var text: String
    
    init(tabID: String) {
        self.tabID = tabID
        self._text = AppStorage(wrappedValue: "", "note_\(tabID)", store: Config.sharedDefaults)
    }
    
    var body: some View {
        TextEditor(text: $text)
    }
}
