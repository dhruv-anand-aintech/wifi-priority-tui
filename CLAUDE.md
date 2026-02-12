# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WiFi Priority TUI is a single-file Python terminal application that provides an interactive interface for reordering macOS WiFi network priorities. It uses the Textual framework for the TUI and interfaces directly with macOS's `networksetup` command.

## Development Setup

```bash
# Install in editable mode for development
uv pip install -e .

# Run the application
wifi-priority

# Or run directly without installation
python wifi_priority.py
```

## Architecture

This is a **single-file application** (`wifi_priority.py`) with three main components:

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

## Testing Considerations

When adding tests, note:
- Mock `subprocess.run()` calls to avoid actual system changes
- The app requires macOS and sudo privileges, so tests should not make real networksetup calls
- Consider testing the list reordering logic, UI state transitions, and change detection separately from system integration

## Packaging

This project is configured as a Python package with an entry point:
- Entry point: `wifi-priority` → `wifi_priority:main`
- Single module: `wifi_priority.py` (no package directory)
- Minimal dependencies: only `textual>=0.47.0`
