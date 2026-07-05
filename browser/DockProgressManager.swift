import Cocoa
import WebKit

class DockProgressManager {
    static let shared = DockProgressManager()
    private var activeDownloads = Set<WKDownload>()
    private var observations = [WKDownload: NSKeyValueObservation]()
    
    private init() {}
    
    func add(download: WKDownload) {
        if activeDownloads.contains(download) { return }
        activeDownloads.insert(download)
        
        let obs = download.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateDockIcon()
            }
        }
        observations[download] = obs
        updateDockIcon()
    }
    
    func remove(download: WKDownload) {
        activeDownloads.remove(download)
        observations[download]?.invalidate()
        observations.removeValue(forKey: download)
        updateDockIcon()
    }
    
    private func updateDockIcon() {
        if activeDownloads.isEmpty {
            NSApp.dockTile.contentView = nil
            NSApp.dockTile.display()
            return
        }
        
        let validDownloads = activeDownloads.filter { $0.progress.totalUnitCount > 0 }
        let averageFraction: Double
        if validDownloads.isEmpty {
            averageFraction = 0.0
        } else {
            let totalFraction = validDownloads.reduce(0.0) { $0 + $1.progress.fractionCompleted }
            averageFraction = totalFraction / Double(validDownloads.count)
        }
        
        let viewSize: CGFloat = 128.0
        let view = NSView(frame: NSRect(x: 0, y: 0, width: viewSize, height: viewSize))
        
        let appIcon = NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)
        let imageView = NSImageView(frame: view.bounds)
        imageView.image = appIcon
        view.addSubview(imageView)
        
        // Progress bar background
        let barHeight: CGFloat = viewSize * 0.12
        let barWidth: CGFloat = viewSize * 0.8
        let barX: CGFloat = (viewSize - barWidth) / 2
        let barY: CGFloat = viewSize * 0.15
        let barRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
        
        let progressBackground = NSView(frame: barRect)
        progressBackground.wantsLayer = true
        progressBackground.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8).cgColor
        progressBackground.layer?.cornerRadius = barHeight / 2
        progressBackground.layer?.borderColor = NSColor.separatorColor.cgColor
        progressBackground.layer?.borderWidth = 1.0
        
        // Progress bar fill
        let fillWidth = max(barHeight, barWidth * CGFloat(averageFraction))
        let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: barHeight)
        let fillView = NSView(frame: fillRect)
        fillView.wantsLayer = true
        fillView.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        fillView.layer?.cornerRadius = barHeight / 2
        
        progressBackground.addSubview(fillView)
        view.addSubview(progressBackground)
        
        NSApp.dockTile.contentView = view
        NSApp.dockTile.display()
    }
}
