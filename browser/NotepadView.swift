import SwiftUI

struct NoteView: View {
    @AppStorage("notepad", store: Config.sharedDefaults) var notepad: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $notepad)
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.1))
                .padding(4)
        }.padding()
        .background(Color.black.opacity(0.1))
    }
}
