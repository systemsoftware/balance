import SwiftUI
import PDFKit

struct PDFKitRepresentedView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displaysAsBook = false
        pdfView.backgroundColor = .clear
        
        Task.detached(priority: .background) {
            if let document = PDFDocument(url: url) {
                await MainActor.run {
                    pdfView.document = document
                }
            }
        }
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Handled via async load in makeNSView
    }
}
