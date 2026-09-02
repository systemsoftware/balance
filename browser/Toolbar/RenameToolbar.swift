import SwiftUI
import WebKit

struct RenameToolbar: View {
    
    @Binding var location: URL?
    @ObservedObject var browserState: BrowserState
    
    @State var newName = ""
    
    @State var showRenameSheet = false
    
    var body: some View {
        
        Button() {
            showRenameSheet = true
        } label: {
            Image(systemName: "pencil")
        }
        .sheet(isPresented: $showRenameSheet) {
            VStack {
                TextField("Enter new tab name:", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                HStack {
                    Button("Cancel") { showRenameSheet = false }
                    Button("Rename") {
                        showRenameSheet = false
                        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedName.isEmpty {
                            browserState.customTitle = nil
                            browserState.title = browserState.webView?.title ?? "Page"
                        } else {
                            browserState.customTitle = trimmedName
                            browserState.title = trimmedName
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .disabled(location == nil)
    }
}
