import SwiftUI


struct SplitViewToolbarButton: View {
    @Binding var splitURL: String
    @ObservedObject var splitState: BrowserState
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    let presentURLSheet: () -> Void
    @EnvironmentObject var windowManager: WindowManager

    private var availableTabs: [BrowserState] {
        windowManager.windows.filter { $0 !== browserState && $0.url != nil }
    }
    
    var body: some View {
        Menu() {
            if(splitURL.isEmpty) {
                Button() {
                    presentURLSheet()
                } label: {
                    Label("Open", systemImage: "plus")
                }
                
                Menu {
                    ForEach(availableTabs, id: \.tabID) { state in
                        Button(state.title) {
                            if let url = state.url {
                                splitURL = url.absoluteString
                            }
                        }
                    }
                } label: {
                    Text("Split with Other Tab")
                }
                .disabled(availableTabs.isEmpty)
                
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
                .foregroundStyle(splitURL.isEmpty ? .primary : Color.accentColor)
        }
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .buttonStyle(.plain)
    }
}
