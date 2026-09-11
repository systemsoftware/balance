import SwiftUI

struct MuteToolbar: View {
    
    @Binding var location: URL?
    @ObservedObject var browserState: BrowserState
    var expandedLabel = false
    
    var body: some View {
        
        Button() {
            browserState.toggleMute()
        } label: {
            ToolbarItemLabel(
                expanded: expandedLabel,
                title: browserState.isAudioMuted ? "Unmute" : "Mute",
                systemImage: browserState.isAudioMuted ? "speaker.slash" : "speaker"
            )
        }
        .buttonStyle(.plain)
        .frame(width: expandedLabel ? nil : 40, height: 40)
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .disabled(location == nil)
    }
}
