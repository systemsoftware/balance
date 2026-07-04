import Foundation
import AppKit
import SwiftUI
internal import Combine

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    @Published var windows: [BrowserState] = []
    
    // Spaces management
    @Published var currentSpaceIndex: Int = 0
    @Published var spaceNames: [String] = ["Space 1"]
}
