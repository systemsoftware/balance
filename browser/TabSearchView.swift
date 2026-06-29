import SwiftUI

struct TabSearchView: View {
    @State private var searchText = ""
    
    @Environment(\.dismiss) private var dismiss

    var filteredWindows: [NSWindow] {
        if searchText.isEmpty {
            return openWindows
        } else {
            return openWindows.filter { window in
                window.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack {
            TextField("Search Tabs", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

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
