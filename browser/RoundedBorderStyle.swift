import SwiftUI
import Foundation

struct RoundedBorderStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var lineWidth: CGFloat = 1
    var color: Color = .gray
    
    @AppStorage("sidebarWidth", store: Config.sharedDefaults)
    private var sidebarWidth: Int = 345

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: lineWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .frame(width: CGFloat(sidebarWidth))
    }
}

struct RoundedBorderStyleNoFrame: ViewModifier {
    var cornerRadius: CGFloat = 20
    var lineWidth: CGFloat = 1
    var color: Color = .gray
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: lineWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func roundedBorderStyle(
        cornerRadius: CGFloat = 20,
        lineWidth: CGFloat = 1,
        color: Color = .gray
    ) -> some View {
        self.modifier(RoundedBorderStyle(
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            color: color
        ))
    }
    
    func roundedBorderStyleNoFrame(
        enabled: Bool = true,
        cornerRadius: CGFloat = 20,
        lineWidth: CGFloat = 1,
        color: Color = .gray
    ) -> some View {
        if enabled == true {
            self.modifier(RoundedBorderStyleNoFrame(
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                color: color
            ))
        } else {
            self.modifier(RoundedBorderStyleNoFrame(cornerRadius: 0, lineWidth: 0, color: .clear))
        }
    }
}
