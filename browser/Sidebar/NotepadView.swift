import SwiftUI
import WebKit

enum NoteScope: String, CaseIterable, Identifiable {
    case global = "Global"
    case currentTab = "This Tab"
    case ephemeral = "Ephemeral"
    case domain = "Domain"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .global: return "globe"
        case .currentTab: return "doc.text"
        case .ephemeral: return "clock"
        case .domain: return "network"
        }
    }
}

struct NoteView: View {
    @AppStorage("notepad", store: Config.sharedDefaults) var notepad: String = ""
    
    @State var tabNote = ""
    var tabID: String = ""
    
    var browserState: BrowserState

    @State var noteScope: NoteScope = .global
    
    var body: some View {
        VStack(spacing: 10) {
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
            }.padding([.top, .horizontal])

            scopePicker
                .padding(.horizontal, 12)

            noteEditor
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .padding([.horizontal, .bottom], 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var availableScopes: [NoteScope] {
        NoteScope.allCases.filter {
            $0 != .domain || browserState.url?.domainID != nil
        }
    }
    
    private func label(for scope: NoteScope) -> String {
        let MAX_CHAR = 16
        if scope == .domain, let domain = browserState.url?.domainID {
            return "\(domain.prefix(MAX_CHAR))\(domain.count > MAX_CHAR ? "…" : "")"
        }
        return scope.rawValue
    }
    
    private var scopePicker: some View {
        Menu {
            ForEach(availableScopes) { scope in
                Button {
                    noteScope = scope
                } label: {
                    Label(label(for: scope), systemImage: scope.icon)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: noteScope.icon)
                    .font(.caption)
                Text(label(for: noteScope))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.secondary.opacity(0.12))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
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
