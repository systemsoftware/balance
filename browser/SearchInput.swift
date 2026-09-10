import SwiftUI

struct SearchInputVisualConfig {
    var cornerRadius: CGFloat = 6
    var height: CGFloat = 22

    var iconName: String = "magnifyingglass"
    var iconColor: Color = .secondary
    var clearIconName: String = "xmark.circle.fill"

    var placeholderText: String = "Search"
    var placeholderColor: Color = .secondary
    var textColor: Color = .primary
    var font: Font = .system(size: 13)

    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 8
    var animation: Animation? = .easeInOut(duration: 0.15)
}

struct SearchInputView: View {
    @Binding var text: String
    var config: SearchInputVisualConfig = SearchInputVisualConfig()
    @State private var isFocused: Bool = false
    
    var placeholder: String?

    private var clearButton: some View {
        Button(action: { withAnimation(config.animation) { text = "" } }) {
            Image(systemName: config.clearIconName)
                .foregroundColor(config.iconColor)
                .font(.system(size: 11))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: config.iconName)
                .foregroundColor(config.iconColor)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 16)

            TextField(placeholder ?? config.placeholderText, text: $text)
                .padding(3)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                clearButton
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, config.horizontalPadding)
        .padding(.vertical, config.verticalPadding)
        .frame(height: config.height)
        .background(
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .fill(Color.platformControlBackground.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: config.cornerRadius)
                        .strokeBorder(Color.platformSeparator.opacity(isFocused ? 0.8 : 0.4), lineWidth: isFocused ? 1.5 : 0.5)
                )
        )
        // Use a single animation modifier to avoid compounding animations
        .animation(config.animation, value: isFocused)
        .animation(config.animation, value: text)
    }
}
