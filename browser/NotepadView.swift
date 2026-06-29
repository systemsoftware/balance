import SwiftUI

struct NoteView: View {
    @AppStorage("notepad", store: Config.sharedDefaults) var notepad: String = ""
    
    @State var tabNote = ""

    @State var thisTabOnly: Bool = false
    
    var body: some View {
        VStack{
            HStack {
                Text("Notepad")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Clear") {
                    notepad = ""
                }
                
                Toggle("This Tab Only", isOn:$thisTabOnly)
            }.padding()
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(
                text: thisTabOnly ? $tabNote : $notepad
            )
                    .scrollContentBackground(.hidden)
                    .padding()
        }
    }
}
