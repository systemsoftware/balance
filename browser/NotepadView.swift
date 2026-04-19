import SwiftUI

struct NoteView: View {
    @AppStorage("notepad", store: Config.sharedDefaults) var notepad: String = ""

    var body: some View {
        VStack{
            HStack {
                Text("Notepad")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Clear") {
                    notepad = ""
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }.padding()
            
                TextEditor(text: $notepad)
                    .scrollContentBackground(.hidden)
                    .padding()
        }
    }
}
