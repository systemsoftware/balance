import SwiftUI

struct CleanupButtonView: View {
    @State private var isDeleting = false
    @State private var statusMessage = "Clean Now"
    
    var body: some View {
        VStack {
            Button(action: {
                isDeleting = true
                statusMessage = "Cleaning up..."
                
                DispatchQueue.global(qos: .userInitiated).async {
                    clearTmpDirectory()
                }
            }) {
                if isDeleting {
                    ProgressView()
                } else {
                    Text(statusMessage.isEmpty ? "Clear Temporary Files" : statusMessage)
                }
            }
            .disabled(isDeleting) // Prevent double-tapping
        }
    }
    
    func clearTmpDirectory() {
            Task {
                let count = await CleanupButtonView.cleanTmp()
                updateUI(message: "Successfully cleared \(count) items!", resetting: true)
            }
    }
    
    @discardableResult
    static func cleanTmp() async -> Int {
        
        let fileManager = FileManager.default
        
        let tmpFolderURL = FileManager.default.temporaryDirectory
                
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: tmpFolderURL, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            
            return fileURLs.count
        } catch {
            print(error)
            return 0
        }
    }
    
    // Helper to pass UI changes back to the main thread
    func updateUI(message: String, resetting: Bool) {
        DispatchQueue.main.async {
            self.statusMessage = message
            if resetting {
                self.isDeleting = false
            }
        }
    }
}
