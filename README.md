# WiFi Priority TUI

Interactive terminal UI for reordering macOS WiFi network priorities.

## Features

- 🎨 Beautiful terminal interface using Textual
- ⌨️ Keyboard-driven navigation (vim-style keys supported)
- 🔄 Real-time reordering with visual feedback
- 💾 Applies changes directly to macOS network preferences
- 🛡️ Safe: shows unsaved changes before exit

## Installation

> **Note**: PyPI package coming soon! For now, install from source.

### From source (current method)

```bash
git clone https://github.com/dhruv-anand-aintech/wifi-priority-tui
cd wifi-priority-tui
uv pip install -e .
```

### Using uv (once published to PyPI)

```bash
uv pip install wifi-priority-tui
```

### Using pip (once published to PyPI)

```bash
pip install wifi-priority-tui
```

## Usage

Simply run:

```bash
wifi-priority
```

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

## Why?

macOS System Settings lets you reorder WiFi networks, but it's buried deep in menus and requires lots of clicking. This tool makes it quick and keyboard-driven.

Perfect for users who:
- Switch between multiple WiFi networks frequently
- Want to prioritize work/home networks
- Need to prevent auto-connecting to certain networks
- Prefer terminal interfaces

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
