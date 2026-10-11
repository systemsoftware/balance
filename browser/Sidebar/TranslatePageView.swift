import SwiftUI
import Translation

struct TranslatePageView: View {
    @State private var text = ""
    @State private var showTranslation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Translate Text")
                .font(.title2.weight(.semibold))
            TextField("Enter text to translate", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...10)
            Button("Translate") { showTranslation = true }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .translationPresentation(isPresented: $showTranslation, text: text)
    }
}
