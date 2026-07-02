import SwiftUI
import WebKit

enum NoteScope: String, CaseIterable, Identifiable {
    case global = "Global"
    case currentTab = "This Tab"
    case ephemeral = "Ephemeral"
    case domain = "Domain"
    
    var id: String { self.rawValue }
}

struct NoteView: View {
    @AppStorage("notepad", store: Config.sharedDefaults) var notepad: String = ""
    
    @State var tabNote = ""
    var tabID: String = ""
    
    var browserState: BrowserState

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
                    case .domain:
                        if let domain = browserState.webView?.url?.domainID {
                            Config.sharedDefaults?.set("", forKey: "note_\(domain)")
                        }
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }.padding()

            
            Picker("", selection: $noteScope) {
                ForEach(
                    NoteScope.allCases.filter {
                        $0 != .domain || browserState.url?.domainID != nil
                    }
                ) { scope in
                    let MAX_CHAR = 10
                    if scope == .domain {
                        Text("\((browserState.url!.domainID!).prefix(MAX_CHAR))\(browserState.url!.domainID!.count > MAX_CHAR ? "..." : "")").tag(scope)
                    } else {
                        Text(scope.rawValue).tag(scope)
                    }
                }
            }
            .pickerStyle(.palette)
            .padding(.horizontal)
            .padding(.leading, -4)
            
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
        case .domain:
            if let domain = browserState.webView?.url?.domainID {
                TabNoteEditor(tabID: domain)
            }
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

extension URL {
    var domainID: String? {
        guard var hostString = self.host?.lowercased() else { return nil }
        
        if hostString.hasPrefix("www.") {
            hostString.removeFirst(4)
        }
        return hostString
    }
}
