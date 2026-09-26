# Balance Browser

**Balance Browser** is a modern, privacy-focused, and highly productive web browser built with **SwiftUI** and **WebKit**. It combines a native macOS experience with powerful built-in productivity tools—including local on-device AI, notepad, tab spaces, split view, RSS reader, interactive map workspace, and seamless iCloud sync—all encased in a customizable sidebar with a beautiful Liquid Glass interface.


## Support
Supports iOS, iPadOS, and macOS 26.0 and later, and can be downloaded on the [App Store.](https://apps.apple.com/us/app/balance-browser/id6789459733)

## Key Highlights

- **Local On-Device AI**: Private chat, page summarization, citation generator, and calendar event extraction powered by Apple Foundation Models.
- **Flexible Workspace**: Split view, tab search, spaces, focus mode, and 6 tab layout styles (Top, Vertical, Slide Over, Compact, Bottom, Hidden).
- **Modular Sidebar & Customizable Toolbar**: Drag-and-drop customization for sidebars and toolbars with instant access to your favorite utilities and pinned sites.
- **Seamless iCloud Sync**: Synchronize history, bookmarks, pins, chats, profiles, inventory, toolbar/sidebar setups, search engines, and settings across your Apple devices.
- **Privacy & Security First**: Zero tracking, WebKit content blocking, per-site permission controls, HTTPS-only mode, Global Privacy Control (GPC), server trust verification, and granular clear-on-exit preferences.
- **Chrome Extensions & App Intents**: Run compatible web extensions and automate browser actions with Apple Shortcuts and Siri.



## Features Showcase

### Productivity

#### Command Palette (`⌘ K`)
Instantly search open tabs, bookmarks, history, and trigger browser commands from a unified quick-action overlay.

![Command Palette](images/palette.png)

#### Productive Sidebar
Access AI Chat, Notes, History, Downloads, Bookmarks, Passwords, Email, Weather, Calendar, RSS feeds, and your pinned websites in one place.

![Sidebar](images/sidebar.png)

#### Split View
Browse two websites side-by-side with resizable proportions and independent navigation.

![Split View](images/split.png)

#### Customizable Toolbar
Add, remove, and reorder toolbar buttons such as Navigation, Reader, Mute, Restyle, Breadcrumbs Trail, AI Tools, and Word Count.

![Toolbar](images/toolbar.png)

#### Focus Mode (`⌘ ⌥ F`)
Eliminate distractions with a minimal, focused reading and working window.

![Focus Mode](images/focus.png)



### Local AI & Intelligence

#### On-Device AI Chat
Chat with a completely private, local AI assistant directly from the sidebar for writing, coding assistance, research, and analysis.

![AI Chat](images/chat.png)

#### AI Page Summarization (`⌘ /`)
Generate concise summaries of articles and lengthy web pages on-device with custom length and temperature controls.

![AI Summarization](images/summary.png)

#### Smart Event Extraction (`⌘ ⌥ /`)
Automatically detect dates, times, and event details on web pages and add them directly to your macOS Calendar with one click.

![Event Extraction](images/events.png)



### Browsing & Utilities

#### Map Workspace
Extract physical locations and addresses mentioned across your tabs and visualize them interactively on Apple Maps.

![Map Workspace](images/map.png)

#### Reader Mode (`⌘ ⌥ R`)
Distraction-free article reader powered by Readability.js.

![Reader Mode](images/reader.png)

#### Page Restyling & Boosts
Customize typography, accent colors, and styling per webpage for improved readability and accessibility.

![Restyle Page](images/restyle.png)

#### Profiles & IMAP Email
Isolate browsing data with separate profiles (including ephemeral sessions) and integrate IMAP accounts to monitor unread emails directly in the sidebar.

![Profiles](images/profile.png)

#### Extensions Support
Install and run compatible extensions from the Chrome Web Store with dedicated popup popovers.

![Extensions](images/ext.png)

#### Tab Search (`⌘ ⌃ S`)
Search across all open tabs, windows, bookmarks, and browsing history with instant keyboard filtering.

![Tab Search](images/search.png)

#### Weather & RSS Feeds
Stay informed with live city forecasts and integrated RSS feed reader widgets in your sidebar.

![Weather](images/weather.png)
![RSS Feeds](images/rss.png)

#### Privacy & Server Trust
Inspect SSL certificate trust chains, manage site permissions, and enforce content blocker rules.

![Server Trust](images/servertrust.png)



## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| **Command Palette** | `⌘ K` |
| **New Tab** | `⌘ T` |
| **New Window** | `⌘ N` |
| **Close Tab** | `⌘ W` |
| **Reopen Closed Tab** | `⌘ ⇧ T` |
| **Search All Tabs** | `⌘ ⌃ S` |
| **Go To URL / Query** | `⌘ G` |
| **Go Back** | `⌘ ←` |
| **Go Forward** | `⌘ →` |
| **Reload Page** | `⌘ R` |
| **Force Reload (Bypass Cache)** | `⌘ ⇧ R` |
| **Find in Page** | `⌘ F` |
| **Zoom In / Out** | `⌘ +` / `⌘ -` |
| **Toggle Reader Mode** | `⌘ ⌥ R` |
| **Toggle Focus Mode** | `⌘ ⌥ F` |
| **AI Summarize Page** | `⌘ /` |
| **AI Add Events to Calendar** | `⌘ ⌥ /` |
| **Add to Bookmarks** | `⌘ D` |
| **Open Downloads** | `⌘ ⇧ D` |
| **Open History** | `⌘ Y` |
| **Toggle Mute** | `⌘ ⇧ M` |
| **Share Link** | `⌘ ⇧ S` |
| **Copy Page URL** | `⌘ ⌃ C` |
| **Save Page As** | `⌘ ⌥ S` |
| **Print Page** | `⌘ P` |



## Tech Stack

- **UI Framework**: SwiftUI & AppKit (Liquid Glass architecture)
- **Web Engine**: WebKit (`WKWebView`, `WKWebsiteDataStore`, `WKContentRuleList`)
- **Persistence & Data**: SwiftData & AppStorage
- **Cloud Synchronization**: iCloud (`NSUbiquitousKeyValueStore` & CloudKit sync)
- **Document Rendering**: PDFKit, Native Markdown view, Native JSON viewer, Readability.js
- **Automation**: AppIntents / macOS Shortcuts & Deep Linking (`balance://`, `balance-focus://`)
- **AI & Intelligence**: Apple Foundation Models / CoreML / MLX on-device processing



## Requirements

- **macOS**: macOS 15.0 (Sequoia) / macOS 26.0+
- **Xcode**: Xcode 16.0+ / Swift 6.0+



## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/systemsoftware/balance.git
   cd balance
   ```
2. Open `Balance.xcodeproj` in Xcode.
3. Select the `browser` macOS target.
4. Build and run (`⌘ R`).



## Configuration & Preferences

Customize Balance through **Settings (`⌘ ,`)**:

- **Browsing**: Default search engine, custom engine shortcuts, homepage, address bar autocomplete, spaces, default page zoom.
- **Appearance**: Theme selection (System, Light, Dark, Match Page), Tab layouts (Top, Vertical, Slide Over, Compact, Bottom, Hidden), background shapes (Capsule, Rounded Rect), toolbar & tab bar styling.
- **Sidebar & Toolbar**: Drag-and-drop customization, width sizing, unified or individual backgrounds, top/bottom toolbar positioning.
- **AI**: Temperature, max tokens, character cutoff thresholds, and custom system prompt instructions.
- **iCloud Sync**: Granular toggles for history, bookmarks, pins, chats, sidebar, toolbar, profiles, settings, inventory, autofill, and custom engines.
- **Privacy & Security**: HTTPS-only mode, Global Privacy Control (GPC), WebKit content blockers, per-site permissions, and automated cleanup on exit (history, cache, cookies, downloads).
- **Profiles**: Create multiple profiles with dedicated storage data, custom search engines, IMAP email integration, or ephemeral private modes.



## License

Licensed under the [MIT License](LICENSE).

## Contact & Community

- Open an issue or discussion on [GitHub](https://github.com/systemsoftware/balance)
- Email: `support@coolstone.dev`
- Mac App Store: [Balance Browser](https://apps.apple.com/us/app/balance-browser/id6789459733)