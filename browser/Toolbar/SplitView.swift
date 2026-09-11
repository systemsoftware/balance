import SwiftUI


struct SplitViewToolbarButton: View {
    @Binding var splitURL: String
    @ObservedObject var splitState: BrowserState
    var expandedLabel = false
    let presentURLSheet: () -> Void
    
    var body: some View {
        Menu() {
            if(splitURL.isEmpty) {
                Button() {
                    presentURLSheet()
                } label: {
                    Label("Open", systemImage: "plus")
                }
            } else {
                
                Button() {
                    createNewTab(with:URL(string:splitURL))
                } label: {
                    Label("Copy to New Tab", systemImage: "plus.square.on.square")
                }
                
                Divider()
                
                Button() {
                    presentURLSheet()
                } label: {
                    Label("Change", systemImage: "link.badge.plus")
                }
                
                Divider()
                
                Button() {
                    splitState.toggleMute()
                } label: {
                    splitState.isAudioMuted ? Label("Unmute", systemImage:"speaker.slash") : Label("Mute", systemImage:"speaker")
                }
                Divider()
                
                Button() {
                    splitURL = ""
                } label: {
                    Label("Close", systemImage: "xmark")
                }
            }
        } label: {
            ToolbarItemLabel(expanded: expandedLabel, title: "Split View", systemImage: "rectangle.split.2x1")
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
    }
}
