# WiFi Priority SwiftUI

Native macOS app for managing WiFi network priorities with a beautiful SwiftUI interface.

## Features

- 🎨 Native macOS design with SwiftUI
- 🖱️ Drag-and-drop network reordering
- 🔐 Secure admin authentication via macOS dialog
- 💾 Real-time change detection
- ⌨️ Keyboard shortcuts (⌘S to save, ⌘Q to quit)

## Building from Xcode

1. Open Xcode
2. Create a new macOS App project:
   - File → New → Project
   - Choose "macOS" → "App"
   - Product Name: `WiFiPrioritySwiftUI`
   - Interface: SwiftUI
   - Language: Swift
   - Bundle Identifier: `com.yourname.WiFiPrioritySwiftUI`

3. Replace the generated files with the source files from this directory:
   - `WiFiPriorityApp.swift`
   - `ContentView.swift`
   - `NetworkManager.swift`

4. Copy `Info.plist` settings if needed

5. Build and run (⌘R)

## Building from Command Line

You can also build using `xcodebuild`:

```bash
# Create Xcode project first (see above)
# Then build from terminal
xcodebuild -scheme WiFiPrioritySwiftUI -configuration Release

# The app will be in:
# ~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/
```

## Quick Build Script

For easier building, use this script:

```bash
#!/bin/bash
# build.sh - Quick build script

# This requires an Xcode project to exist
xcodebuild clean build \
    -scheme WiFiPrioritySwiftUI \
    -configuration Release \
    -derivedDataPath ./build

echo "✅ Build complete!"
echo "App location: ./build/Build/Products/Release/WiFiPrioritySwiftUI.app"
```

## Usage

1. Launch the app
2. Networks are displayed in current priority order (highest first)
3. Drag networks to reorder them
4. Press "Save & Quit" (or ⌘S) to apply changes
5. Enter your admin password when prompted

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later
- WiFi adapter (typically en0)

## How It Works

The app uses the same `networksetup` command as the TUI version:
- Reads network list: `networksetup -listpreferredwirelessnetworks en0`
- Applies changes using AppleScript with admin privileges
- Networks are removed and re-added in reverse order (last added = highest priority)

## Screenshots

The app features:
- Clean header with WiFi icon and title
- Instructions panel
- Draggable network list with position numbers
- Status bar showing unsaved changes
- Save/Reset/Quit action buttons

## Comparison with TUI Version

| Feature | TUI (Python) | SwiftUI (Native) |
|---------|-------------|------------------|
| Interface | Terminal-based | Native macOS GUI |
| Reordering | Space + Arrow keys | Drag and drop |
| Platform | macOS terminal | macOS app |
| Distribution | PyPI package | App bundle |
| Dependencies | Python + Textual | None (native) |

## License

MIT License - see parent directory LICENSE file
