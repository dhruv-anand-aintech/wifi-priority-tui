# WiFi Priority SwiftUI

Native macOS app for managing WiFi network priorities with a beautiful SwiftUI interface.

## Features

- 🎨 Native macOS design with SwiftUI
- 🖱️ Drag-and-drop network reordering
- 🔐 Secure admin authentication via macOS dialog
- 💾 Real-time change detection
- ⌨️ Keyboard shortcuts (⌘S to save, ⌘Q to quit, Esc to reset)

## Quick Build

```bash
./build.sh
open build/WiFiPrioritySwiftUI.app
```

## Building from Xcode

1. Open Xcode
2. Create a new macOS App project:
   - File → New → Project
   - Choose "macOS" → "App"
   - Product Name: `WiFiPrioritySwiftUI`
   - Interface: SwiftUI
   - Language: Swift

3. Add the Swift files to your project:
   - `WiFiPriorityApp.swift`
   - `ContentView.swift`
   - `NetworkManager.swift`

4. Build and run (⌘R)

## Usage

1. Launch the app
2. Networks are displayed in current priority order (highest first)
3. Drag networks to reorder them
4. Press "Save & Quit" (or ⌘S) to apply changes
5. Enter your admin password when prompted

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (for build.sh)
- WiFi adapter (typically en0)

## Architecture

- **WiFiPriorityApp.swift**: App entry point and window configuration
- **NetworkManager.swift**: Business logic, networksetup command integration
- **ContentView.swift**: SwiftUI UI with modular subviews

Uses AppleScript to prompt for admin password when saving changes.

## License

MIT License - see parent directory LICENSE file
