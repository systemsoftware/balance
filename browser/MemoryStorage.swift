import SwiftUI

@Observable
class MemoryStorage {
    static let shared = MemoryStorage()
    
    var focusMode = false
    var showTabOverview = false
    
    private init() {}
}
