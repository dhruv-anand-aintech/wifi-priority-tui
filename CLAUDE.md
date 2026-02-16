# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains **two implementations** of a WiFi network priority manager for macOS:

1. **TUI (Terminal)**: Single-file Python application (`wifi_priority.py`) using the Textual framework
2. **SwiftUI (Native)**: macOS app in the `WiFiPrioritySwiftUI/` directory with native drag-and-drop interface

Both implementations use macOS's `networksetup` command to read and modify WiFi network priorities.

## Development Setup

### TUI (Python)

```bash
# Install in editable mode for development
uv pip install -e .

# Run the application
wifi-priority

# Or run directly without installation
python wifi_priority.py
```

### SwiftUI (macOS)

```bash
cd WiFiPrioritySwiftUI

# Option 1: Build with script (requires Xcode command line tools)
./build.sh
open build/WiFiPrioritySwiftUI.app

# Option 2: Open in Xcode
# Create new macOS App project and add the Swift files
# See WiFiPrioritySwiftUI/README.md for details
```

## Architecture

### TUI Version (`wifi_priority.py`)

This is a **single-file application** with three main components:

### 1. NetworkListItem (Widget)
Custom Textual widget that displays individual WiFi network names in the list. Contains only presentation logic.

### 2. WiFiReorderApp (Main TUI)
Textual App that manages the interactive interface:
- Maintains two lists: `self.networks` (current state) and `self.original_networks` (for change detection)
- Handles keyboard bindings for navigation and reordering
- Manages UI state including status messages and visual feedback
- Coordinates save/quit actions

### 3. System Integration Functions
- `get_preferred_networks(interface="en0")`: Reads current WiFi priority list from macOS using `networksetup -listpreferredwirelessnetworks`
- `_apply_network_priority()`: Applies new priority order by removing all networks and re-adding them in reverse order (macOS adds networks at index 0, making the last added network the highest priority)

### SwiftUI Version (`WiFiPrioritySwiftUI/`)

The SwiftUI app is structured as a standard macOS application with three main files:

#### 1. WiFiPriorityApp.swift (Entry Point)
Defines the app structure and window configuration.

#### 2. NetworkManager.swift (Business Logic)
- ObservableObject that manages network state using `@Published` properties
- Handles asynchronous loading and saving of network priorities
- Uses AppleScript to execute `sudo networksetup` commands (prompts for admin password)
- Implements the same reverse-order network addition pattern as the TUI version
- Custom `NetworkError` enum for type-safe error handling

#### 3. ContentView.swift (UI Layer)
- Main view with subviews for each UI section (Header, Instructions, List, Status, Actions)
- Uses SwiftUI's List with `.onMove()` modifier for native drag-and-drop reordering
- Reactive UI updates via `@StateObject` and `@Binding`
- Keyboard shortcuts: ⌘S (save), ⌘Q (quit), Esc (reset)

## Key Implementation Details

### macOS Integration
The app interfaces with macOS's WiFi priority system through the `networksetup` command:
- **Read**: `networksetup -listpreferredwirelessnetworks en0` returns networks in priority order (highest priority first)
- **Write**: Uses `sudo` to remove and re-add networks. Networks are added in **reverse order** because `networksetup -addpreferredwirelessnetworkatindex` always adds at index 0, making the last-added network the highest priority.

### State Management Pattern
```python
self.networks = networks.copy()           # Current working state
self.original_networks = networks.copy()  # Immutable reference for change detection
```
Changes are only applied when user explicitly saves. The status bar warns about unsaved changes.

### UI Rebuild Pattern
When networks are reordered, the entire ListView is rebuilt rather than swapping items in place. This ensures the UI stays synchronized with the underlying data model:
```python
def _rebuild_list(self) -> None:
    list_view.clear()
    for network in self.networks:
        list_view.append(NetworkListItem(network))
```

## Platform Requirements

- **macOS only**: Uses the `networksetup` command-line utility
- **sudo required**: Network priority changes require administrator privileges
- **WiFi interface**: Assumes `en0` as the WiFi interface (standard for most Macs)

## Code Signing & Distribution Notes

### Ad-hoc Signing (Current)
- **Status**: App is signed with ad-hoc signature (no certificate)
- **Gatekeeper Warning**: Yes, when downloaded directly from GitHub
- **Homebrew Install**: No warning (Homebrew bypasses Gatekeeper)
- **User Workaround**: `xattr -d com.apple.quarantine /Applications/WiFi\ Priority.app`

### Developer ID Signing (Optional - Requires $99 Developer Program)
To eliminate Gatekeeper warnings for direct downloads:
1. Enroll in Apple Developer Program
2. Create Developer ID Application certificate
3. Build with: `./build.sh "Developer ID Application: Name (ID)"`
4. (Optional) Notarize the app for maximum trust

## Testing Considerations

When adding tests, note:
- Mock `subprocess.run()` calls to avoid actual system changes
- The app requires macOS and sudo privileges, so tests should not make real networksetup calls
- Consider testing the list reordering logic, UI state transitions, and change detection separately from system integration

## Packaging & Distribution

### Python Package
This project is configured as a Python package with an entry point:
- Entry point: `wifi-priority` → `wifi_priority:main`
- Single module: `wifi_priority.py` (no package directory)
- Minimal dependencies: only `textual>=0.47.0`
- Published on PyPI: https://pypi.org/project/wifi-priority-tui/

### Homebrew Distribution
Both versions are distributed via Homebrew through a custom tap repository:
- **Tap repo**: https://github.com/dhruv-anand-aintech/homebrew-tap
- **SwiftUI app cask**: `brew install wifi-priority`
- **Python TUI formula**: `brew install wifi-priority-tui`

## Release Workflow

Releasing new versions is automated via GitHub Actions:

### 1. Build and Test Locally
```bash
# Build SwiftUI app
cd WiFiPrioritySwiftUI && ./build.sh

# Build Python distributions
python -m build

# Test both apps before releasing
./build/WiFiPrioritySwiftUI.app  # Test macOS app
sudo python -m wifi_priority      # Test TUI
```

### 2. Create Release
```bash
# Create GitHub release with both distributions
gh release create v0.5.0 \
  WiFiPrioritySwiftUI-0.5.0.zip \
  dist/wifi_priority_tui-0.5.0* \
  --title "v0.5.0 - Feature Description" \
  --notes "Release notes here"
```

### 3. Automated Homebrew Tap Update (GitHub Action)
Once the release is published, a GitHub Action automatically:
1. Downloads release assets (app zip + source tarball)
2. Calculates SHA256 checksums
3. Updates `Casks/wifi-priority.rb` (SwiftUI version & checksum)
4. Updates `Formula/wifi-priority-tui.rb` (Python TUI version & checksum)
5. Commits and pushes changes to the Homebrew tap repo

**No manual steps needed!** The workflow uses the `TAP_REPO_TOKEN` secret which is already configured.

### Version Format
- Versions follow semantic versioning: `v0.4.9`, `v0.5.0`, etc.
- Update `pyproject.toml` version before building
- Update SwiftUI `Info.plist` CFBundleShortVersionString before building
- GitHub Actions automatically detects version from the git tag

### Backup & Restore Features (v0.4.9+)
Both versions now support automatic backups:
- **Automatic backups**: Timestamped files saved to `~/.wifi-priority-backups/`
- **Backup management**: Keeps last 10 backups, older ones auto-deleted
- **SwiftUI restore**: Button appears when no changes are pending
- **Python TUI CLI**:
  - `wifi-priority --backup-info` - View backup metadata
  - `sudo wifi-priority --restore-latest` - Restore from latest backup
