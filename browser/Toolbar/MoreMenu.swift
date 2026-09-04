import SwiftUI


struct MoreMenuToolbar: View {
    let items: [ToolbarItemType]
    let itemContent: (ToolbarItemType) -> AnyView

    var body: some View {
        Menu {
            if items.isEmpty {
                Text("All toolbar items are visible")
                    .disabled(true)
            } else {
                ForEach(items) { item in
                    if item != .spacer && item != .autocomplete && item != .addressBar && item != .rename && item != .extensions {
                        itemContent(item)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("More")
    }
}
