import SwiftUI

struct FindInPageToolbarButton: View {
    @ObservedObject var browserState: BrowserState
    
    var body: some View {
    
        if !browserState.isFindBarVisible {
            
            Button() {
                presentFindBar()
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
            }
            .glassEffect(.regular.interactive(), in:.circle)
            .buttonStyle(.plain)
            .disabled(browserState.url == nil)
            
        } else {
            FindBarView(state: browserState)
        }
        
    }


    private func presentFindBar() {
        // The clicked button is replaced by the find field. Let AppKit detach the
        // button from the key-view loop before SwiftUI removes its hosting view.
        NSApp.keyWindow?.makeFirstResponder(nil)
        Task { @MainActor in
            await Task.yield()
            browserState.isFindBarVisible = true
        }
    }
}
