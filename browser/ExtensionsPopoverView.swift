import SwiftUI
import WebKit

struct ExtensionsPopoverView: View {
    @ObservedObject private var manager = WebExtensionManager.shared
    @State private var selectedAction: WKWebExtension.Action? = nil
    
    var body: some View {
        Group {
            if let action = selectedAction {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            selectedAction = nil
                        }) {
                            Image(systemName: "chevron.backward")
                            Text("Back")
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        
                        Spacer()
                        
                        Text(action.webExtensionContext?.webExtension.displayName ?? "")
                            .font(.headline)
                            .padding(.trailing, 8)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    ExtensionActionPopupView(action: action)
                }
            } else {
                VStack(spacing: 0) {
                    Text("Extensions")
                        .font(.headline)
                        .padding(.vertical, 10)
                    
                    Text("Manage extensions in the sidebar")
                        .font(.caption)
                        .padding(.bottom, 5)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if manager.contexts.isEmpty {
                                Text("No extensions found.")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 20)
                            } else {
                                ForEach(manager.contexts, id: \.self) { context in
                                    ExtensionActionRow(context: context) { action in
                                        if action.presentsPopup {
                                            selectedAction = action
                                        } else {
                                            if let tab = manager.activeTab {
                                                context.performAction(for: tab)
                                            } else {
                                                context.performAction(for: nil)
                                            }
                                        }
                                    }
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ExtensionActionRow: View {
    let context: WKWebExtensionContext
    let onAction: (WKWebExtension.Action) -> Void
    @ObservedObject private var manager = WebExtensionManager.shared
    
    @State private var icon: NSImage?
    @State private var title: String = ""
    
    var body: some View {
        Button(action: {
            if let action = getAction() {
                onAction(action)
            }
        }) {
            HStack {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .frame(width: 24, height: 24)
                }
                
                Text((title.isEmpty ? context.webExtension.displayName : title) ?? "")
                    .font(.body)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            updateInfo()
        }
    }
    
    private func getAction() -> WKWebExtension.Action? {
        return context.action(for: manager.activeTab)
    }
    
    private func updateInfo() {
        guard let action = getAction() else { return }
        self.icon = action.icon(for: CGSize(width: 24, height: 24))
        self.title = (action.label.isEmpty ? context.webExtension.displayName : action.label) ?? ""
    }
}
