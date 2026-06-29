# Balance Browser

**Balance Browser** is a streamlined, modern web browser for macOS built entirely with **SwiftUI** and **WebKit**. It focuses on a balanced workflow by integrating essential productivity tools—like notes, history, and AI directly into a customizable sidebar alongside a beautiful Liquid Glass interface.

## Key Features

* **Smart Address Bar**: Intelligently handles direct URLs, domain shorthand (e.g., `google.com`), and automatically converts text queries into Google searches.
* **Productive Sidebar**: A multi-functional sidebar that supports:
    * **Built-in Views**: Instant access to Local AI Chat (Apple Foundation Models), Bookmarks, Settings, Notes, History, and Downloads.
    * **Web Pins**: Pin any website (like Spotify, Slack, or Discord) to the sidebar for split-screen browsing.
* **Liquid Glass UI**: A native macOS aesthetic utilizing depth and translucency.
* **Advanced Tabs & Windows**: Support for duplicating tabs, launching pages into new windows, and **Tab Search** for quickly finding open pages.
* **Reader Mode**: Distraction-free reading environment leveraging Readability.js.
* **Privacy & Security**: Built-in **Content Blocking**, **Site Permissions** management, and **Server Trust** verification.
* **Extensions Support**: Customize and extend the browser's capabilities.
* **AutoFill & Commands**: Quick access to commands and search autocomplete.
* **Customizable Experience**:
    * **User Agent Switching**: Modify how the browser identifies itself to websites.
    * **Bookmark Bar Modes**: Choose between `Hidden`, `New Tab Only`, or `Always`.
    * **Persistent Storage**: History, bookmarks, downloads, and site permissions are managed via **SwiftData**.
* **Profiles:** Seperate website data with distinct window profiles

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
- Required for Sidebar WebView & Apple Foundation Models

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