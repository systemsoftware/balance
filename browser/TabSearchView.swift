import SwiftUI

struct TabSearchView: View {
    @State var searchText = ""
    
    var showSearch = true
    
    @Environment(\.dismiss) private var dismiss

    var filteredWindows: [NSWindow] {
        let validWindows = NSApp.windows.filter { window in
            window.styleMask.contains(.titled) && 
            window.styleMask.contains(.resizable) && 
            window.className != "NSPanel"
        }
        
        if searchText.isEmpty {
            return validWindows
        } else {
            return validWindows.filter { window in
                window.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack {
            
            if showSearch {
                
                TextField("Search Tabs", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
            }

            List(filteredWindows, id: \.windowNumber) { window in
                Button(action: {
                    window.makeKeyAndOrderFront(nil)
                    dismiss()
                }) {
                    Text(window.title.isEmpty ? "Untitled Tab" : window.title)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}
