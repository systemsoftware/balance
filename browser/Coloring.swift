#if canImport(UIKit)
import UIKit
typealias UniversalColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias UniversalColor = NSColor
#endif

extension UniversalColor {
    static func from(rgbString: String) -> UniversalColor? {
        let values = rgbString.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .filter { !$0.isEmpty }.compactMap { Double($0).map { CGFloat($0) } }
        guard values.count >= 3 else { return nil }
        return UniversalColor(red: values[0] / 255, green: values[1] / 255,
                              blue: values[2] / 255, alpha: values.count >= 4 ? values[3] : 1)
    }

    var isLight: Bool {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return true }
        #else
        guard let color = usingColorSpace(.deviceRGB) else { return true }
        let red = color.redComponent, green = color.greenComponent, blue = color.blueComponent
        #endif
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.5
    }

    var isTransparent: Bool {
        #if canImport(UIKit)
        cgColor.alpha == 0
        #else
        alphaComponent == 0
        #endif
    }
}
