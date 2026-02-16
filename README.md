# WiFi Priority TUI

Interactive terminal UI for reordering macOS WiFi network priorities.

**Also available:** Native SwiftUI macOS app in the [`WiFiPrioritySwiftUI/`](WiFiPrioritySwiftUI/) directory!

## Features

- 🎨 Beautiful terminal interface using Textual
- ⌨️ Keyboard-driven navigation (vim-style keys supported)
- 🔄 Real-time reordering with visual feedback
- 💾 Applies changes directly to macOS network preferences
- 🛡️ Safe: shows unsaved changes before exit

## Installation

### Using uv (recommended)

```bash
uv pip install wifi-priority-tui
```

### Using pip

```bash
pip install wifi-priority-tui
```

### From source

```bash
git clone https://github.com/dhruv-anand-aintech/wifi-priority-tui
cd wifi-priority-tui
uv pip install -e .
```

## Usage

**Important:** This app requires administrator privileges to modify network settings.

```bash
sudo wifi-priority
```

If you try to run without `sudo`, the app will exit with instructions.

### Keyboard Controls

- **↑/↓** or **k/j** - Navigate through networks
- **Ctrl+↑** or **Ctrl+k** - Move selected network up (higher priority)
- **Ctrl+↓** or **Ctrl+j** - Move selected network down (lower priority)
- **s** - Save changes and exit
- **q** - Quit without saving

## Requirements

- macOS (uses `networksetup` command)
- Python 3.8+
- WiFi adapter (typically `en0`)

## How It Works

The app:
1. Reads your current WiFi network priority list from macOS
2. Displays them in an interactive TUI
3. Lets you reorder them with keyboard shortcuts
4. Applies changes using `sudo networksetup` commands

Networks at the top of the list have higher priority. macOS will automatically connect to the highest priority network available.

## Two Versions Available

### 🖥️ TUI (Terminal) - This Package
Python-based terminal interface with keyboard-driven navigation. Perfect for terminal enthusiasts and SSH sessions.

**Install via pip:**
```bash
pip install wifi-priority-tui
sudo wifi-priority
```

### 🎨 SwiftUI (Native macOS)
Native macOS app with drag-and-drop interface.

**Install via Homebrew:**
```bash
brew install --cask dhruv-anand-aintech/tap/wifi-priority
```

Or build from source - see [`WiFiPrioritySwiftUI/`](WiFiPrioritySwiftUI/) for details.

## Why?

macOS System Settings lets you reorder WiFi networks, but it's buried deep in menus and requires lots of clicking. These tools make it quick and easy.

**TUI version** is perfect for users who:
- Switch between multiple WiFi networks frequently
- Want to prioritize work/home networks
- Need to prevent auto-connecting to certain networks
- Prefer terminal interfaces
- Work primarily in SSH sessions

**SwiftUI version** is great for users who:
- Prefer native macOS apps
- Like drag-and-drop interfaces
- Want a visual representation
- Use macOS GUI primarily

## Screenshots

```
╭──────────────────────────────────────────────────────────╮
│ 🛜  WiFi Network Priority Manager                        │
├──────────────────────────────────────────────────────────┤
│ 📋 Drag networks to change priority (higher = preferred) │
│    Use ↑↓ or k/j to select, Ctrl+↑↓ to move, 's' to save│
├──────────────────────────────────────────────────────────┤
│ ┏━ WiFi Networks (Priority Order) ━━━━━━━━━━━━━━━━━━━━┓ │
│ ┃   Home Network 5G                                    ┃ │
│ ┃ ▶ Office WiFi                                        ┃ │
│ ┃   Coffee Shop Guest                                  ┃ │
│ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
│ ⚠️  Changes not saved! Press 's' to save or 'q' to quit  │
╰──────────────────────────────────────────────────────────╯
```

## License

MIT License - see [LICENSE](LICENSE) file for details

## Related Projects

- [wifi-failover-utility](https://github.com/dhruv-anand-aintech/wifi-failover-utility) - Automatic WiFi failover to Android hotspot

## Contributing

Issues and pull requests welcome!
