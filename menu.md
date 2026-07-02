# How to Add a New Menu Item

The macOS menu bar in Balance is fully data-driven. You do not need to write any SwiftUI `Button` or `Menu` code to add new options. Everything is controlled by the `BrowserCommand` enum.

Follow these 3 simple steps to add a new item:

### 1. Add a new case to `BrowserCommand`
Open `browserApp.swift` and find the `BrowserCommand` enum. Add a new case for your action.

```swift
enum BrowserCommand: String, CaseIterable {
    // ...
    case myNewFeature
}
```

### 2. Define the Command Properties
In the same enum, scroll down and define the properties for your new command in the computed variables. 

> [!IMPORTANT]
> The order of the cases in the enum determines the order they appear in the menu!

- **`title`**: The display name of the button.
```swift
var title: String {
    switch self {
    // ...
    case .myNewFeature: return "My Awesome Feature"
    }
}
```

- **`section`**: Which top-level menu it goes into (`.browser` or `.page`).
```swift
var section: MenuBarSection {
    switch self {
    case .palette, .searchTabs, .myNewFeature:
        return .browser
    // ...
    }
}
```

- **`submenu` (Optional)**: If you want it inside a nested menu (like "Zoom" or "Developer"), return the name of the folder. Otherwise, return `nil`.
```swift
var submenu: String? {
    switch self {
    case .myNewFeature: return "Developer" // Puts it in the Developer folder
    // ...
    }
}
```

- **`shortcut` (Optional)**: Assign a keyboard shortcut.
```swift
var shortcut: KeyboardShortcut? {
    switch self {
    case .myNewFeature: return KeyboardShortcut("n", modifiers: [.command, .shift])
    // ...
    }
}
```

- **`requiresDividerAfter`**: Return `true` if you want a horizontal line to appear underneath your item.

### 3. Add the Execution Logic
Finally, open `ContentView.swift` and locate `.focusedSceneValue(\.dispatchBrowserCommand)`. Add your new case to the `switch` statement and provide the logic!

```swift
.focusedSceneValue(\.dispatchBrowserCommand) { command in
    switch command {
    // ...
    case .myNewFeature:
        print("My new feature was clicked!")
        // Or toggle a state: showMyFeature.toggle()
    }
}
```

> [!TIP]  
> Because the switch statement is inside `ContentView`, you have direct access to all of its variables (like `browserState`, `@State` properties, etc.).

And that's it! The UI will automatically generate the button exactly where you told it to.