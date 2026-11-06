import SwiftUI
import PDFKit

struct PDFKitRepresentedView: PlatformViewRepresentable {
    let url: URL

    @MainActor
    final class Coordinator {
        private var requestedURL: URL?
        private var loadTask: Task<Void, Never>?

        func load(_ url: URL, into pdfView: PDFView) {
            guard requestedURL != url else { return }

            loadTask?.cancel()
            requestedURL = url
            pdfView.document = nil

            loadTask = Task { [weak self, weak pdfView] in
                do {
                    let data: Data
                    if url.isFileURL {
                        data = try await Task.detached(priority: .userInitiated) {
                            try Data(contentsOf: url)
                        }.value
                    } else {
                        let (downloadedData, response) = try await URLSession.shared.data(from: url)
                        if let response = response as? HTTPURLResponse,
                           !(200...299).contains(response.statusCode) {
                            return
                        }
                        data = downloadedData
                    }

                    guard !Task.isCancelled, self?.requestedURL == url,
                          let pdfView, let document = PDFDocument(data: data) else { return }
                    pdfView.document = document
                } catch {
                    // Leave the view empty when the document cannot be loaded.
                }
            }
        }

        func cancel() {
            loadTask?.cancel()
            loadTask = nil
            requestedURL = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func makePDFView() -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displaysAsBook = false
        pdfView.backgroundColor = .clear
        return pdfView
    }

    #if canImport(AppKit)
    func makeNSView(context: Context) -> PDFView {
        let pdfView = makePDFView()
        context.coordinator.load(url, into: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.load(url, into: pdfView)
    }

    static func dismantleNSView(_ pdfView: PDFView, coordinator: Coordinator) {
        coordinator.cancel()
    }
    #else
    func makeUIView(context: Context) -> PDFView {
        let pdfView = makePDFView()
        context.coordinator.load(url, into: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.load(url, into: pdfView)
    }

    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        coordinator.cancel()
    }
    #endif
}
