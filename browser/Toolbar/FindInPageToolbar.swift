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
            .frame(width: 40, height: 40)
            .glassEffect(.regular.interactive(), in:.circle)
            .buttonStyle(.plain)
            .disabled(browserState.url == nil)
            
        } else {
            FindBarView(state: browserState)
                .frame(height: 40)
        }
        
    }


    private func presentFindBar() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        Task { @MainActor in
            await Task.yield()
            browserState.isFindBarVisible = true
        }
    }
}
