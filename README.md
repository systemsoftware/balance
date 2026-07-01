# Balance Browser

**Balance Browser** is a streamlined, modern web browser for macOS built entirely with **SwiftUI** and **WebKit**. It focuses on a balanced workflow by integrating essential productivity tools—like notes, history, and AI directly into a customizable sidebar alongside a beautiful Liquid Glass interface.

## Feature Showcase

### Command Palette
Instantly access browser commands, execute actions, and navigate efficiently.
![Command Palette](images/palette.png)

### Productive Sidebar
A multi-functional sidebar that hosts built-in tools like Notes, History, and Downloads, alongside your favorite pinned websites.
![Sidebar](images/sidebar.png)

### Local AI Chat
Engage with a local AI assistant directly in your browser. Ask questions, brainstorm, and get help seamlessly and locally.
![AI Chat](images/chat.png)

### Split View
Browse two websites at a time.
![Split View](images/split.png)

### Map Workspace
Automatically extract locations and real-world entities from your open tabs and plot them on an interactive map.
![Map](images/map.png)

### AI Page Summarization
Quickly digest long articles or complex web pages using local Apple Foundation Models.
![Summary](images/summary.png)

### Event Extraction
Intelligently detect event details on a page and instantly export them to your macOS Calendar.
![Events](images/events.png)

### Focus Mode
A distraction-free environment designed to help you concentrate on a single task or reading material.
![Focus](images/focus.png)

### Smart Address Bar
Intelligently handles direct URLs, domain shorthand (e.g., `google.com`), and automatically converts text queries into Google searches.

### Liquid Glass UI
A native macOS aesthetic utilizing depth and translucency.

### Advanced Tabs & Windows
Support for duplicating tabs, launching pages into new windows, and Tab Search for quickly finding open pages.

### Notepad
A built-in scratchpad right in the sidebar to jot down thoughts while you browse.

![Notes](images/notes.png)

### Native PDF Viewer
Seamlessly read and view PDF documents directly within the browser with PDFKit.

### Reader Mode
Distraction-free reading environment (powered by Readability.js).

![Reader](images/reader.png)

### Privacy & Security
Built-in Content Blocking, Site Permissions management, and Server Trust verification.

### Extensions Support
Customize and extend the browser's capabilities.

### Customizable Experience
Modify how the browser identifies itself (User Agent Switching), adjust Bookmark Bar Modes, and manage your data with persistent storage.

### Profiles
Separate website data with distinct window profiles.

## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| **Go Back** | `⌘ + [←]` |
| **Go Forward** | `⌘ + [→]` |
| **Reload Page** | `⌘ + R` |
| **Find in Page** | `⌘ + F` |
| **Share Link** | `⌘ + ⇧ + S` |
| **Copy Page URL** | `⌘ + ⌃ + C` |

## Tech Stack

* **Framework**: SwiftUI
* **Engine**: WebKit (`WKWebView`)
* **Data Persistence**: SwiftData & AppStorage (UserDefaults)
* **Interface**: AppKit integration for window management and clipboard control.
* **Scripting**: JavaScript (Readability.js for Reader Mode)

## Getting Started

### Prerequisites
* **macOS 26.0+** (Tahoe) or later 
- Required for AppKit, Sidebar WebView, and Apple Foundation Models

### Installation
1. Clone the repository.
2. Open the `.xcodeproj` in Xcode.
3. Ensure the target is set to **macOS**.
4. Build and Run (`⌘ + R`).

### Configuration
You can customize the default behavior via the `SettingsView` (accessible via the sidebar):
* **Homepage**: Set your preferred landing page or use the local `home.html`.
* **User Agent**: Switch between Safari, Chrome, or custom strings for specialized browsing.
* **History**: Toggle "Record History" to browse privately without saving to the SwiftData store.

## License

This project is licensed under the MIT License - see the LICENSE file for details.