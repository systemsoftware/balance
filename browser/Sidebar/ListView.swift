import SwiftUI

struct SidebarListItem: View {
    let item: SidebarItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.icon)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.view?.replacingOccurrences(of: "View", with: "") ?? "")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.platformWindowBackground.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SidebarListView: View {
 
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    var sidebarWidth: Int = 345
    @Binding var sidebarURL: URL?
    
    @State var searchText: String = ""
    
    @State var openInNewTab = 0
    
    var filtered: [SidebarItem] {
        if searchText.isEmpty {
            return builtInSidebar.sorted { $0.view ?? "" < $1.view ?? "" }
        }
        
        return builtInSidebar.filter {
            $0.view?.localizedCaseInsensitiveContains(searchText) ?? false
        }
        .sorted { $0.view ?? "" < $1.view ?? "" }
    }
    
    var body: some View {
        
        VStack {
            HStack {
                Text("Built-in Pages")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }
            .padding(.leading)
            VStack(spacing: 0) {
                
                SearchInputView(text:$searchText)
                    .padding(.horizontal)
                    .padding(.bottom, 2)

                ScrollView {
        
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("No built-in pages match your search.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(filtered) { site in
                                SidebarListItem(
                                    item: site,
                                    action: {
                                        let url = URL(string:"balance://\(site.view?.replacingOccurrences(of: "View", with: "") ?? "")".lowercased())!
                                        if openInNewTab == 1 {
                                                createNewTab(with: url, inBackground: false)
                                        } else {
                                            sidebarURL = url
                                        }
                                    }
                                )
                            }
                        }
                        .padding(16)
                        
                        
                        Picker("Open in", selection: $openInNewTab) {
                            Text("Sidebar").tag(0)
                            Text("New Tab").tag(1)
                        }
                                            .padding(.horizontal)
                                            .padding(.top, 8)
                                            .padding(.bottom, 8)
                                            .pickerStyle(.segmented)
                                    
                    }
                }
                .frame(minWidth: CGFloat(sidebarWidth))
                
                
            }
            .background(Color.black.opacity(0.03))
        }
        .padding(.top)
    }
}
