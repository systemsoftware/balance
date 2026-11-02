import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeSidebar: View {
    var browserState: BrowserState

    @State private var sourceData = ""
    @State private var image: UniversalImage?

    private let context = CIContext()

    private var trimmedSource: String {
        sourceData.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("QR Code")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Current URL") {
                    guard let url = browserState.url?.absoluteString else { return }
                    sourceData = url
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(browserState.url == nil)
            }
            .padding(16)

            VStack(alignment: .leading, spacing: 16) {
                TextField("Enter text or URL", text: $sourceData, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onChange(of: sourceData) { image = nil }

                Button {
                    image = generateQRCode(from: trimmedSource)
                } label: {
                    Text("Generate QR Code")
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedSource.isEmpty)

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.02))
    }

    private var preview: some View {
        VStack(spacing: 12) {
            if let image {
                Image(universalImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Generated QR code")
                
                ShareLink(item: image, preview: SharePreview("QR Code", image: Image(universalImage: image))) {
                    Label("Share QR Code", systemImage: "square.and.arrow.up")
                }
                
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("No QR code yet")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func generateQRCode(from string: String) -> UniversalImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UniversalImage(cgImage: cgImage, size: outputImage.extent.size)
    }
}
