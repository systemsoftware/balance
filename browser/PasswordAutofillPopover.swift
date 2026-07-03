import SwiftUI
import AppKit
import LocalAuthentication

struct PasswordAutofillView: View {
    let domain: String
    let credentials: [SavedCredential]
    var onSelect: (SavedCredential) -> Void
    var onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !credentials.isEmpty {
                Text("Use Saved Password")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                
                ForEach(credentials) { cred in
                    AutofillRowButton(
                        icon: "key.fill",
                        iconColor: .accentColor,
                        title: cred.username,
                        action: {
                            authenticate(reason: "authenticate to autofill your password") {
                                onSelect(cred)
                            }
                        }
                    )
                }
                
                Divider().padding(.vertical, 2)
            }
            
            AutofillRowButton(
                icon: "plus.circle.fill",
                iconColor: .green,
                title: "Save Current Password",
                action: onSave
            )
        }
        .padding(6)
        .frame(minWidth: 220)
    }
    
    private func authenticate(reason: String, completion: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        completion()
                    }
                }
            }
        } else {
            completion()
        }
    }
}

struct AutofillRowButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 16)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

class AutofillPopoverManager {
    static let shared = AutofillPopoverManager()
    private var popover: NSPopover?
    
    func show(relativeTo rect: NSRect, in view: NSView, domain: String, credentials: [SavedCredential], onSelect: @escaping (SavedCredential) -> Void, onSave: @escaping () -> Void) {
        if popover == nil {
            let newPopover = NSPopover()
            newPopover.behavior = .transient
            self.popover = newPopover
        }
        
        let contentView = PasswordAutofillView(domain: domain, credentials: credentials) { [weak self] cred in
            self?.hide()
            onSelect(cred)
        } onSave: { [weak self] in
            self?.hide()
            onSave()
        }
        
        popover?.contentViewController = NSHostingController(rootView: contentView)
        
        // Shift the rect down by its height, and give it 0 height,
        // so that .maxY (which anchors to the top of the rect) anchors to the bottom of the input.
        let shiftedRect = NSRect(x: rect.minX, y: rect.minY + rect.height, width: rect.width, height: 0)
        popover?.show(relativeTo: shiftedRect, of: view, preferredEdge: .maxY)
    }
    
    func hide() {
        popover?.close()
    }
}
