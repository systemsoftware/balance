import SwiftUI

struct Command: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let action: () -> Void
}

let commands: [Command] = [
    Command(
        name: "New Tab",
        systemImage: "plus.square.on.square",
        action: {
            createNewTab()
        }
    ),
    Command(name: "New Window", systemImage: "macwindow.badge.plus", action: {
        createNewWindow()
    }),
    Command(name: "New Private Window", systemImage: "eye.slash.fill", action: {
        createNewWindow(pvt:true)
    }),
    Command(name: "New Window At", systemImage: "macwindow.badge.plus", action: {
        let alert = NSAlert()
        alert.informativeText = "Enter the URL to go to:"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "https://example.com"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let url = URL(string: input.stringValue)
        createNewWindow(with:url, pvt:true)
    }),
    Command(name: "New Private Window At", systemImage: "eye.slash.fill", action: {
        let alert = NSAlert()
        alert.informativeText = "Enter the URL to go to:"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "https://example.com"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let url = URL(string: input.stringValue)
        createNewWindow(with:url)
    }),
]

struct CommandsView: View {
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var filteredCommands: [Command] {
        if searchText.isEmpty {
            commands
        } else {
            commands.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        List(filteredCommands) { command in
            Button {
                command.action()
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: command.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    Text(command.name)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.inset)
        .navigationTitle("Commands")
        .searchable(text: $searchText, prompt: "Search commands")
        .frame(minWidth: 420, minHeight: 350)
    }
}
