import SwiftUI

struct MuteToolbar: View {
    
    @Binding var location: URL?
    @ObservedObject var browserState: BrowserState
    
    var body: some View {
        
        Button() {
            browserState.toggleMute()
        } label: {
            browserState.isAudioMuted ? Image(systemName:"speaker.slash") : Image(systemName: "speaker")
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .disabled(location == nil)
    }
}
