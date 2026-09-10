import SwiftUI
import PDFKit

struct PDFKitRepresentedView: PlatformViewRepresentable {
    let url: URL
    
    private func makePDFView() -> PDFView {
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
    
    #if canImport(AppKit)
    func makeNSView(context: Context) -> PDFView { makePDFView() }
    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Handled via async load in makeNSView
    }
    #else
    func makeUIView(context: Context) -> PDFView { makePDFView() }
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Handled via async load in makeUIView
    }
    #endif
}
