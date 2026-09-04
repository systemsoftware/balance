import SwiftUI

struct TabSearchView: View {
    @State var searchText = ""
    
    var showSearch = true
    
    @Environment(\.dismiss) private var dismiss
    
    var isPopover = false
    
    @EnvironmentObject var windowManager: WindowManager
    
    var store = PinStore()
    
    var filteredStates: [BrowserState] {
        if searchText.isEmpty {
            return windowManager.windows
        } else {
            return windowManager.windows.filter { state in
                state.title.localizedCaseInsensitiveContains(searchText) || (state.url?.absoluteString.localizedCaseInsensitiveContains(searchText) ?? false)
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

            ForEach(filteredStates, id: \.self) { state in
                Button(action: {
                    switchToTab(tabID: state.tabID)
                    
                    if isPopover {
                        dismiss()
                    }
                    
                }) {
                    WindowRow(browserState: state)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Menu {

                        if store.items.first(where: { $0.url == state.url?.absoluteString }) == nil {
                            Button("Pin") {
                                store.add(Bookmark(
                                    title: state.title,
                                    url: state.url?.absoluteString ?? ""
                                ))
                            }
                        } else {
                            Button("Unpin") {
                                store.remove(url: state.url?.absoluteString ?? "")
                            }
                        }

                        
                    } label: {
                        Text("Options")
                    }
                }

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct WindowRow: View {
    @ObservedObject var browserState: BrowserState

    var body: some View {
        HStack(spacing: 8) {
            CachedAsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(browserState.url?.host ?? "")")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 16, height: 16)

            Text(browserState.title.isEmpty ? "Untitled Tab" : browserState.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerSize: CGSize(width: 16, height: 16)))
    }
}
