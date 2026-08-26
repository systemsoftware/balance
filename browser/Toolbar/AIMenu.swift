import SwiftUI
import WebKit


struct AIMenuToolbar: View {
    
    @ObservedObject var passwordManager = PasswordManager.shared
    @ObservedObject var browserState: BrowserState
    @Binding var location: URL?
    
    @State var summarizing = false
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
                Task {
                    summarizing = true
                    await createSummaryWindow(state: browserState)
                    summarizing = false
                }
            } label: {
                Label("Summarize", systemImage: "text.line.3.summary")
            }
            
        } label: {
            if summarizing || scanningForEvents {
                ProgressView()
                    .scaleEffect(2)
            } else {
                Image(systemName: "sparkles.2")
            }
        }
        .disabled(location == nil)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
        
    }
}
