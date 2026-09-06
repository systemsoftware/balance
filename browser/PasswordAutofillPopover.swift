import SwiftUI
import LocalAuthentication
import AppKit

func autofillIconAndColor(for type: String, label: String?) -> (icon: String, color: Color) {
    let lowerType = type.lowercased()
    let lowerLabel = (label ?? "").lowercased()
    
    if lowerType == "password" || lowerLabel.contains("password") {
        return ("key.fill", .orange)
    } else if lowerType == "email" || lowerLabel.contains("email") || lowerLabel.contains("mail") {
        return ("envelope.fill", .blue)
    } else if lowerType == "tel" || lowerType == "phone" || lowerLabel.contains("phone") || lowerLabel.contains("tel") || lowerLabel.contains("mobile") {
        return ("phone.fill", .green)
    } else if lowerLabel.contains("address") || lowerLabel.contains("street") || lowerLabel.contains("city") || lowerLabel.contains("zip") || lowerLabel.contains("postal") {
        return ("mappin.circle.fill", .red)
    } else if lowerLabel.contains("name") || lowerLabel.contains("user") || lowerType == "name" {
        return ("person.fill", .purple)
    } else if lowerType == "url" || lowerLabel.contains("website") || lowerLabel.contains("link") {
        return ("link", .cyan)
    } else if lowerType == "number" || lowerLabel.contains("number") {
        return ("number", .indigo)
    } else {
        return ("text.cursor", .accentColor)
    }
}

struct AutofillPopoverView: View {
    let domain: String
    let inputType: String
    let inputLabel: String
    let currentValue: String
    let credentials: [SavedCredential]
    let autofillItems: [AutoFillItem]
    
    var onSelectCredential: (SavedCredential) -> Void
    var onSelectAutofillData: (String) -> Void
    var onSavePassword: () -> Void
    var onSaveAutofill: (String, String, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // MARK: - Passwords Section
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
                                onSelectCredential(cred)
                            }
                        }
                    )
                }
                
                Divider().padding(.vertical, 2)
            }
            
            // MARK: - General Autofill Items Section
            if !autofillItems.isEmpty {
                let sectionTitle: String = {
                    if !inputLabel.isEmpty {
                        return "Fill \(inputLabel)"
                    } else if !inputType.isEmpty && inputType != "text" {
                        return "Fill \(inputType.capitalized)"
                    } else {
                        return "Autofill Information"
                    }
                }()
                
                Text(sectionTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                
                ForEach(autofillItems) { item in
                    let styling = autofillIconAndColor(for: item.type, label: item.label)
                    let displayTitle = item.label?.isEmpty == false ? item.label! : item.data
                    let displaySubtitle = (item.label?.isEmpty == false && item.label != item.data) ? item.data : nil
                    
                    AutofillRowButton(
                        icon: styling.icon,
                        iconColor: styling.color,
                        title: displayTitle,
                        subtitle: displaySubtitle,
                        action: {
                            onSelectAutofillData(item.data)
                        }
                    )
                }
                
                Divider().padding(.vertical, 2)
            }
            
            // MARK: - Empty State
            if credentials.isEmpty && autofillItems.isEmpty && currentValue.isEmpty {
                let emptyMsg = !inputLabel.isEmpty ? "No saved autofill for \(inputLabel)" : "No saved autofill items"
                Text(emptyMsg)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            
            // MARK: - Action Buttons
            if inputType == "password" || !credentials.isEmpty {
                AutofillRowButton(
                    icon: "plus.circle.fill",
                    iconColor: .green,
                    title: "Save Current Password",
                    action: onSavePassword
                )
            } else if !currentValue.isEmpty {
                let saveLabel = !inputLabel.isEmpty ? "Save \"\(currentValue.prefix(20))\" for \(inputLabel)" : "Save \"\(currentValue.prefix(20))\""
                AutofillRowButton(
                    icon: "plus.circle.fill",
                    iconColor: .green,
                    title: saveLabel,
                    action: {
                        onSaveAutofill(currentValue, inputType, inputLabel)
                    }
                )
            }
        }
        .padding(6)
        .frame(minWidth: 230)
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

// Keep PasswordAutofillView as an alias/wrapper for backward compatibility
struct PasswordAutofillView: View {
    let domain: String
    let credentials: [SavedCredential]
    var onSelect: (SavedCredential) -> Void
    var onSave: () -> Void
    
    var body: some View {
        AutofillPopoverView(
            domain: domain,
            inputType: "password",
            inputLabel: "Password",
            currentValue: "",
            credentials: credentials,
            autofillItems: [],
            onSelectCredential: onSelect,
            onSelectAutofillData: { _ in },
            onSavePassword: onSave,
            onSaveAutofill: { _, _, _ in }
        )
    }
}

struct AutofillRowButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
    private let toolbarAnchors = NSHashTable<NSView>.weakObjects()

    func registerToolbarAnchor(_ view: NSView) {
        toolbarAnchors.add(view)
    }
    
    func show(
        relativeTo rect: NSRect,
        in view: NSView,
        domain: String,
        inputType: String = "text",
        inputLabel: String = "",
        currentValue: String = "",
        credentials: [SavedCredential] = [],
        autofillItems: [AutoFillItem] = [],
        onSelectCredential: @escaping (SavedCredential) -> Void = { _ in },
        onSelectAutofillData: @escaping (String) -> Void = { _ in },
        onSavePassword: @escaping () -> Void = {},
        onSaveAutofill: @escaping (String, String, String) -> Void = { _, _, _ in }
    ) {
        if popover == nil {
            let newPopover = NSPopover()
            newPopover.behavior = .transient
            self.popover = newPopover
        }
        
        guard view.window != nil else { return }
        
        if popover?.isShown == true {
            popover?.close()
        }
        
        let contentView = AutofillPopoverView(
            domain: domain,
            inputType: inputType,
            inputLabel: inputLabel,
            currentValue: currentValue,
            credentials: credentials,
            autofillItems: autofillItems,
            onSelectCredential: { [weak self] cred in
                self?.hide()
                onSelectCredential(cred)
            },
            onSelectAutofillData: { [weak self] data in
                self?.hide()
                onSelectAutofillData(data)
            },
            onSavePassword: { [weak self] in
                self?.hide()
                onSavePassword()
            },
            onSaveAutofill: { [weak self] data, type, label in
                self?.hide()
                onSaveAutofill(data, type, label)
            }
        )
        
        popover?.contentViewController = NSHostingController(rootView: contentView)
        
        let toolbarAnchor = toolbarAnchors.allObjects.last {
            $0.window === view.window &&
            !$0.isHiddenOrHasHiddenAncestor &&
            $0.bounds.width > 0 &&
            $0.bounds.height > 0
        }

        guard let toolbarAnchor else { return }

        popover?.show(
            relativeTo: toolbarAnchor.bounds,
            of: toolbarAnchor,
            preferredEdge: .minY
        )
    }
    
    func hide() {
        popover?.close()
    }
}

struct AutofillToolbarPopoverAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = AutofillToolbarAnchorView()
        AutofillPopoverManager.shared.registerToolbarAnchor(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        AutofillPopoverManager.shared.registerToolbarAnchor(nsView)
    }
}

private final class AutofillToolbarAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private extension NSView {
    var isHiddenOrHasHiddenAncestor: Bool {
        var candidate: NSView? = self
        while let view = candidate {
            if view.isHidden { return true }
            candidate = view.superview
        }
        return false
    }
}
