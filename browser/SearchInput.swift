import SwiftUI

struct SearchInputVisualConfig {
    var cornerRadius: CGFloat = 6
    var height: CGFloat = 22

    var iconName: String = "magnifyingglass"
    var iconColor: Color = Color(nsColor: .tertiaryLabelColor)
    var clearIconName: String = "xmark.circle.fill"

    var placeholderText: String = "Search"
    var placeholderColor: Color = Color(nsColor: .placeholderTextColor)
    var textColor: Color = Color(nsColor: .labelColor)
    var font: Font = .system(size: 13)

    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 8
    var animation: Animation? = .easeInOut(duration: 0.15)
}

// MARK: - NSViewRepresentable wrapper
//
// SwiftUI's FocusBridge deadlocks while resolving the key-view loop on
// macOS 26/27 beta whenever a TextField backed by @FocusState is clicked.
// Using NSViewRepresentable keeps the text field out of that path entirely.
// The IsolatedSearchField subclass also severs the key-view chain so the
// system cannot traverse into SwiftUI-managed views when focus is set.
final class IsolatedSearchField: NSTextField {
    override var nextKeyView: NSView? {
        get { nil }
        set { /* intentionally ignored */ }
    }
    override var previousKeyView: NSView? { nil }
    override var nextValidKeyView: NSView? { nil }
    override var previousValidKeyView: NSView? { nil }
}

struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> IsolatedSearchField {
        let field = IsolatedSearchField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize - 2)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: IsolatedSearchField, context: Context) {
        context.coordinator.parent = self
        // Do not overwrite text while the user is typing.
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeSearchField

        init(parent: NativeSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }
    }
}

// MARK: - SearchInputView

struct SearchInputView: View {
    @Binding var text: String
    var config: SearchInputVisualConfig = SearchInputVisualConfig()
    @State private var isFocused: Bool = false
    
    var placeholder: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: config.iconName)
                .foregroundColor(config.iconColor)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 16)

            NativeSearchField(
                text: $text,
                placeholder: placeholder ?? config.placeholderText,
                onFocusChange: { focused in
                    withAnimation(config.animation) { isFocused = focused }
                }
            )

            if !text.isEmpty {
                Button(action: {
                    withAnimation(config.animation) { text = "" }
                }) {
                    Image(systemName: config.clearIconName)
                        .foregroundColor(config.iconColor)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, config.horizontalPadding)
        .padding(.vertical, config.verticalPadding)
        .frame(height: config.height)
        .background(
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: config.cornerRadius)
                        .strokeBorder(
                            isFocused
                                ? Color(nsColor: .keyboardFocusIndicatorColor).opacity(0.7)
                                : Color(nsColor: .separatorColor).opacity(0.6),
                            lineWidth: isFocused ? 2 : 0.5
                        )
                )
        )
        .animation(config.animation, value: isFocused)
        .animation(config.animation, value: text.isEmpty)
    }
}
