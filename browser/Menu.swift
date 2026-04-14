import SwiftUI

struct MoreMenu<Label: View, Content: View>: View {
    let label: Label
    let content: Content

    init(@ViewBuilder label: () -> Label,
         @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            label
        }
    }
}
