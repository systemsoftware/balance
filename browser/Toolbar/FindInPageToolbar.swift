import SwiftUI

struct FindInPageToolbarButton: View {
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    
    var body: some View {
    
        if !browserState.isFindBarVisible {
            
            Button() {
                presentFindBar()
            } label: {
                ToolbarItemLabel(expanded: expandedLabel, title: "Find in Page", systemImage: "doc.text.magnifyingglass")
            }
            .frame(width: expandedLabel ? nil : 40, height: 40)
            .buttonStyle(.plain)
            .disabled(browserState.url == nil)
            
        } else {
            FindBarView(state: browserState)
                .frame(height: 40)
        }
        
    }


    private func presentFindBar() {
        PlatformApplication.dismissKeyboard()
        Task { @MainActor in
            await Task.yield()
            browserState.isFindBarVisible = true
        }
    }
}
