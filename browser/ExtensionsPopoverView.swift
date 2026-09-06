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
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.backward")
                                    .font(.body.weight(.medium))
                                Text("Back")
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(action.webExtensionContext?.webExtension.displayName ?? "")
                            .font(.headline)
                            .lineLimit(1)
                            
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.clear)
                    .layoutPriority(1)
                    
                    Divider()
                        .layoutPriority(1)
                    
                    ExtensionActionPopupView(action: action)
                       
                }
            } else {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extensions")
                            .font(.headline)
                        
                        Text("Manage extensions in the sidebar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(spacing: 4) {
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
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
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
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            if let action = getAction() {
                onAction(action)
            }
        }) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.secondary)
                }
                
                Text((title.isEmpty ? context.webExtension.displayName : title) ?? "")
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovered = hover
        }
        .onAppear {
            updateInfo()
        }
    }
    
    private func getAction() -> WKWebExtension.Action? {
        return context.action(for: manager.activeTab)
    }
    
    private func updateInfo() {
        guard let action = getAction() else { return }
        self.icon = action.icon(for: CGSize(width: 15, height: 15))
        self.title = (action.label.isEmpty ? context.webExtension.displayName : action.label) ?? ""
    }
}
