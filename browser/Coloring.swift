import AppKit

extension NSColor {
    static func from(rgbString: String) -> NSColor? {
        let components = rgbString.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .filter { !$0.isEmpty }
            .compactMap { CGFloat(Double($0) ?? 0) }
        
        guard components.count >= 3 else { return nil }
        
        let red = components[0] / 255.0
        let green = components[1] / 255.0
        let blue = components[2] / 255.0
        let alpha = components.count >= 4 ? components[3] : 1.0
        
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    var isLight: Bool {
        guard let rgb = usingColorSpace(.deviceRGB) else { return true }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance > 0.5
    }
}
