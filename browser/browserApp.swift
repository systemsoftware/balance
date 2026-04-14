import SwiftUI

@main
struct browserApp: App {
    
    @StateObject var tabManager = TabManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(tabManager)
        }
    }
}
