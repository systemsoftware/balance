import SwiftUI


struct SplitViewToolbarButton: View {
    @Binding var splitURL: String
    @ObservedObject var splitState: BrowserState
    @State private var isEditingURL = false
    @State private var draftURL = ""
    
    var body: some View {
        Menu() {
            if(splitURL.isEmpty) {
                Button() {
                    draftURL = ""
                    isEditingURL = true
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
                    draftURL = splitURL
                    isEditingURL = true
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
            Image(systemName: "rectangle.split.2x1")
                .font(.title2)
                .frame(width: Layout.toolbarButtonSize, height: Layout.toolbarButtonSize)
        }
        .frame(width: 40, height: 40)
        .buttonStyle(.plain)
        .alert("Split View URL", isPresented: $isEditingURL) {
            TextField("https://example.com", text: $draftURL)
            Button("Cancel", role: .cancel) {}
            Button("Go") {
                splitURL = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .disabled(draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter the URL to show beside the current page.")
        }
    }
}
