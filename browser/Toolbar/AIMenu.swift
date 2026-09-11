import SwiftUI
import WebKit


struct AIMenuToolbar: View {
    
    @ObservedObject var passwordManager = PasswordManager.shared
    @ObservedObject var browserState: BrowserState
    @Binding var location: URL?
    var expandedLabel = false
    @Binding var summarizing: Bool
    let presentSummarySheet: () -> Void

    @State var scanningForEvents = false
    
    
    let scanEvents: () async -> Void
    
    var body: some View {
        Menu {
            
            Button {
                
                Task {
                    scanningForEvents = true
                    await scanEvents()
                    scanningForEvents = false
                }
                
            } label: {
                Label("Add Events to Calendar", systemImage: "calendar")
            }
            
            Button {
                presentSummarySheet()
            } label: {
                Label("Summarize", systemImage: "text.line.3.summary")
            }
            
        } label: {
            if summarizing || scanningForEvents {
                ProgressView()
                    .scaleEffect(2)
            } else {
                ToolbarItemLabel(expanded: expandedLabel, title: "AI Tools", systemImage: "sparkles.2")
            }
        }
        .disabled(location == nil)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: expandedLabel ? nil : 40, height: 40)
    }
}
