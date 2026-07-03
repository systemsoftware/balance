import SwiftUI
import AppKit
internal import Combine
import WebKit

extension Color {
    func toHex() -> String? {
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

struct BoostView: View {
    @State private var selectedColor = Color.blue
    @State private var isResetting = false
    @State private var useCustomBackground = false
    @State private var useCustomFont = false
    @State private var customCSS: String = ""
    @StateObject private var fontManager = FontManager.shared
    
    @Environment(\.dismiss) var dismiss
    
    var browserState: BrowserState
    var profile: String
    
    private var host: String {
        browserState.url?.host ?? "default"
    }
    
    private var settingsKey: String {
        let p = profile.isEmpty ? "default" : profile
        return "boost_\(p)_\(host)"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Restyle Page")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {


                HStack {
                    Label("Page Color", systemImage: "paintpalette")
                        .foregroundStyle(.secondary)

                    Spacer()

                    if useCustomBackground {
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                        Button("Default") {
                            useCustomBackground = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Custom") {
                            useCustomBackground = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                HStack {
                    Label("Font", systemImage: "textformat.size")
                        .foregroundStyle(.secondary)

                    Spacer()

                    if useCustomFont {
                        Button(action: { fontManager.openFontPicker() }) {
                            Text(fontManager.selectedFontName)
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Default") {
                            useCustomFont = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Custom") {
                            useCustomFont = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                DisclosureGroup() {
                    TextEditor(text: $customCSS)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                } label: {
                    Text("Custom CSS")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                }
                
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )

            VStack(spacing: 12) {

                Text("Preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(useCustomBackground ? selectedColor.gradient : Color.clear.gradient)
                    .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140)
                    .overlay(
                        Text("Aa")
                            .font(useCustomFont ? .custom(fontManager.selectedFontName, size: 40) : .system(size: 40))
                            .foregroundStyle(useCustomBackground ? .white : .primary)
                            .shadow(radius: useCustomBackground ? 4 : 0)
                    )
                    .shadow(color: useCustomBackground ? selectedColor.opacity(0.3) : .clear, radius: 12, x: 0, y: 6)
            }
            
            HStack {
                Button("Apply") {
                    updateWebViewStyle()
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Reset") {
                    resetSettings()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .onAppear {
            loadSettings()
        }
        .onChange(of: selectedColor) { _, newColor in
            guard !isResetting else { return }
            updateWebViewStyle()
            saveSettings()
        }
        .onChange(of: fontManager.selectedFontName) { _, newFont in
            guard !isResetting else { return }
            updateWebViewStyle()
            saveSettings()
        }
        .onChange(of: useCustomBackground) { _, _ in
            guard !isResetting else { return }
            updateWebViewStyle()
            saveSettings()
        }
        .onChange(of: useCustomFont) { _, _ in
            guard !isResetting else { return }
            updateWebViewStyle()
            saveSettings()
        }
        .onChange(of: customCSS) { _, _ in
            guard !isResetting else { return }
            updateWebViewStyle()
            saveSettings()
        }
    }
    
    private func updateWebViewStyle() {
        guard let webView = browserState.webView else { return }
        
        var css = ""
        
        if useCustomBackground {
            let hexColor = selectedColor.toHex() ?? "#0000FF"
            css += "body { background-color: \(hexColor) !important; }\n"
        }
        
        if useCustomFont {
            let fontName = fontManager.selectedFontName
            css += "* { font-family: \"\(fontName)\", -apple-system, sans-serif !important; }\n"
        }
        
        if !customCSS.isEmpty {
            css += customCSS + "\n"
        }
        
        guard let jsCSSString = String(data: try! JSONEncoder().encode(css), encoding: .utf8) else { return }
        
        let jsCode = """
        (function() {
            var styleId = 'app-boost-style-override';
            var styleElement = document.getElementById(styleId);
            
            if (!styleElement) {
                styleElement = document.createElement('style');
                styleElement.id = styleId;
                document.head.appendChild(styleElement);
            }
            
            styleElement.textContent = \(jsCSSString);
        })();
        """
        
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    private func loadSettings() {
        if let hex = Config.sharedDefaults?.string(forKey: "\(settingsKey)_color"),
           let color = Color(hex: hex) {
            selectedColor = color
            useCustomBackground = true
        } else {
            useCustomBackground = false
        }
        
        if let font = Config.sharedDefaults?.string(forKey: "\(settingsKey)_font") {
            fontManager.selectedFontName = font
            useCustomFont = true
        } else {
            useCustomFont = false
        }
        
        if let css = Config.sharedDefaults?.string(forKey: "\(settingsKey)_css") {
            customCSS = css
        }
    }
    
    private func saveSettings() {
        if useCustomBackground, let hex = selectedColor.toHex() {
            Config.sharedDefaults?.set(hex, forKey: "\(settingsKey)_color")
        } else {
            Config.sharedDefaults?.removeObject(forKey: "\(settingsKey)_color")
        }
        
        if useCustomFont {
            Config.sharedDefaults?.set(fontManager.selectedFontName, forKey: "\(settingsKey)_font")
        } else {
            Config.sharedDefaults?.removeObject(forKey: "\(settingsKey)_font")
        }
        
        if !customCSS.isEmpty {
            Config.sharedDefaults?.set(customCSS, forKey: "\(settingsKey)_css")
        } else {
            Config.sharedDefaults?.removeObject(forKey: "\(settingsKey)_css")
        }
    }
    
    private func resetSettings() {
        isResetting = true
        
        Config.sharedDefaults?.removeObject(forKey: "\(settingsKey)_color")
        Config.sharedDefaults?.removeObject(forKey: "\(settingsKey)_font")
        Config.sharedDefaults?.removeObject(forKey: "\(settingsKey)_css")
        
        selectedColor = .blue
        fontManager.selectedFontName = "-apple-system"
        useCustomBackground = false
        useCustomFont = false
        customCSS = ""
        
        guard let webView = browserState.webView else { 
            DispatchQueue.main.async { self.isResetting = false }
            return 
        }
        let jsCode = """
        (function() {
            var styleElement = document.getElementById('app-boost-style-override');
            if (styleElement) {
                styleElement.remove();
            }
        })();
        """
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
        
        DispatchQueue.main.async {
            self.isResetting = false
        }
    }
}

class FontManager: NSObject, ObservableObject {
    @Published var selectedFontName: String = "-apple-system"
    
    static let shared = FontManager()

    func openFontPicker() {
        let fontManager = NSFontManager.shared
        let fontPanel = NSFontPanel.shared
        fontPanel.setPanelFont(NSFont(name: "Helvetica", size: 16)!, isMultiple: false)
        fontManager.target = self
        fontManager.action = #selector(changeFont(_:))
        fontPanel.orderFront(nil)
    }

    @objc func changeFont(_ sender: Any?) {
        let fontManager = NSFontManager.shared
        let dummyFont = NSFont(name: "Helvetica", size: 16)!
        let newFont = fontManager.convert(dummyFont)
        
        self.selectedFontName = newFont.familyName ?? newFont.fontName
    }
}
