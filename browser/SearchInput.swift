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

            TextField(placeholder ?? config.placeholderText,
                text: $text,
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
