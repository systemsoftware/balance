import SwiftUI


struct SplitViewToolbarButton: View {
    @Binding var splitURL: String
    @ObservedObject var splitState: BrowserState
    
    var body: some View {
        Menu() {
            if(splitURL.isEmpty) {
                Button() {
                    let alert = NSAlert()
                    alert.informativeText = "Enter split view URL:"
                    alert.addButton(withTitle: "Go")
                    alert.addButton(withTitle: "Cancel")
                    
                    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                    input.placeholderString = "https://example.com"
                    alert.accessoryView = input
                    alert.window.initialFirstResponder = input
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        
                        splitURL = input.stringValue
                        
                    }
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
                    splitURL = ""
                    
                    let alert = NSAlert()
                    alert.informativeText = "Enter split view URL:"
                    alert.addButton(withTitle: "Go")
                    alert.addButton(withTitle: "Cancel")
                    
                    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                    input.placeholderString = "https://example.com"
                    alert.accessoryView = input
                    alert.window.initialFirstResponder = input
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        splitURL = input.stringValue
                        
                    }
                    
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
        .glassEffect(.regular.interactive(), in:.circle)
        .buttonStyle(.plain)
    }
}
