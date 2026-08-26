import SwiftUI
import WebKit


struct MoreMenuToolbar: View {
    
    @ObservedObject var passwordManager = PasswordManager.shared
    @ObservedObject var browserState: BrowserState
    @Binding var location: URL?
    
    @State var summarizing = false
    
    @Binding var showBoost: Bool
    
    var body: some View {
        Menu {
           
            if let url = location {
               
                
                Menu() {
                    Button() {
                        browserState.zoomIn()
                    } label: {
                        Label("In", systemImage:"plus.magnifyingglass")
                    }
                    
                    Button() {
                        browserState.zoomOut()
                    } label: {
                        Label("Out", systemImage:"minus.magnifyingglass")
                    }
                    
                    Divider()
                    
                    Button() {
                        browserState.resetZoom()
                    } label: {
                        Label("Reset", systemImage: "arrow.clockwise.circle")
                    }
                } label: {
                    Label("Zoom", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                }
                
                Divider()
                
      /*          if !paletteShowTabs {
                    Button() {
                        showTabSearch = true
                    } label: {
                        Label("Search Tabs", systemImage: "rectangle.and.text.magnifyingglass")
                    }
                }
                
                Divider()
         */
                Button() {
                    browserState.toggleMute()
                } label: {
                    browserState.isAudioMuted ? Label("Unmute Tab", systemImage:"speaker.slash") : Label("Mute Tab", systemImage:"speaker")
                }
                
                Divider()
                
                Button() {
                    showBoost = true
                } label: {
                    Label("Restyle Page", systemImage:"paintpalette")
                }
                
                Divider()
                
                Menu {
                    
                    Button("In This Window", systemImage: "plus.square.on.square") {
                        createNewTab(with: url)
                    }
                    Button("In New Window", systemImage: "macwindow.badge.plus") {
                        createNewWindow(with: url)
                    }
                    
                    
                    Divider()
                    
                    Button {
                        createFocusWindow(with: url)
                    } label: {
                        Label("Open in Focus", systemImage: "macwindow")
                    }
                    
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                
                Divider()
                
                Button("Copy Page URL", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
                
                Divider()
                
                    Button() {
                        let alert = NSAlert()
                        alert.informativeText = "Enter new tab name:"
                        alert.addButton(withTitle: "Rename")
                        alert.addButton(withTitle: "Cancel")
                        
                        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                        input.stringValue = browserState.customTitle ?? browserState.title
                        input.placeholderString = browserState.webView?.title ?? "Page"
                        alert.accessoryView = input
                        alert.window.initialFirstResponder = input
                        
                        if alert.runModal() == .alertFirstButtonReturn {
                            let newTitle = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if newTitle.isEmpty {
                                browserState.customTitle = nil
                                browserState.title = browserState.webView?.title ?? "Page"
                            } else {
                                browserState.customTitle = newTitle
                                browserState.title = newTitle
                            }
                        }
                    } label: {
                        Label("Rename Tab", systemImage: "pencil")
                    }
         
                
            } else {
                Text("No active page...")
            }
            
        } label: {
            Image(systemName: "ellipsis")
                .font(.title2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 40, height: 40)
        .glassEffect(.regular.interactive(), in: .circle)
    }
    
}
