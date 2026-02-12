#!/usr/bin/env python3
"""
Interactive TUI for reordering macOS WiFi network priorities.
"""

import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.reactive import reactive
from textual.widgets import Footer, Header, ListItem, ListView, Static


class NetworkListItem(ListItem):
    """A list item that displays a WiFi network name."""

    def __init__(self, network_name: str) -> None:
        super().__init__()
        self.network_name = network_name
        self.label = Static(f"  {network_name}", classes="network-label")

    def compose(self) -> ComposeResult:
        yield self.label


class WiFiReorderApp(App):
    """TUI app for reordering WiFi network priorities."""

    CSS = """
    Screen {
        background: $surface;
    }

    #header-text {
        width: 100%;
        content-align: center middle;
        padding: 1;
        background: $primary;
        color: $text;
    }

    #instructions {
        width: 100%;
        padding: 1;
        background: $panel;
        color: $text;
        border: solid $primary;
    }

    ListView {
        height: 1fr;
        border: solid $accent;
        margin: 1;
    }

    ListView:focus {
        border: solid $accent;
    }

    ListItem {
        padding: 0 1;
        background: transparent;
    }

    ListItem:hover {
        background: $accent 30%;
    }

    /* Selected item - make it very visible */
    ListView > ListItem.-active {
        background: $accent;
        color: $text;
        text-style: bold;
    }

    /* Extra emphasis when focused */
    ListView:focus > ListItem.-active {
        background: $warning;
        color: $text;
        text-style: bold;
    }

    .network-label {
        width: 100%;
    }

    #status {
        width: 100%;
        height: 3;
        padding: 1;
        background: $panel;
        color: $warning;
    }
    """

    BINDINGS = [
        Binding("space", "toggle_reorder_mode", "Reorder Mode", show=True),
        Binding("r", "request_remove", "Remove Network", show=True),
        Binding("s", "save", "Save & Exit", show=True),
        Binding("q", "quit", "Quit", show=True),
    ]

    # Track whether we're in reorder mode
    reorder_mode: reactive[bool] = reactive(False)
    # Track pending removal
    pending_removal_index: reactive[int | None] = reactive(None)

    def __init__(self, networks: List[str], interface: str = "en0"):
        super().__init__()
        self.networks = networks.copy()
        self.original_networks = networks.copy()
        self.interface = interface

    def compose(self) -> ComposeResult:
        """Create child widgets."""
        yield Header()
        yield Static(
            "🛜  WiFi Network Priority Manager",
            id="header-text"
        )
        yield Static(
            "📋 Higher position = preferred network\n"
            "   SPACE: reorder mode • r: remove network • s: save • q: quit",
            id="instructions"
        )

        list_view = ListView(id="network-list")
        list_view.border_title = "WiFi Networks (Priority Order)"
        yield list_view

        yield Static("", id="status")
        yield Footer()

    def on_mount(self) -> None:
        """Populate the list when app starts."""
        list_view = self.query_one("#network-list", ListView)

        for network in self.networks:
            list_view.append(NetworkListItem(network))

        # Ensure ListView is focused so selection is visible
        list_view.focus()
        self.update_status()

    def update_status(self) -> None:
        """Update the status message."""
        status = self.query_one("#status", Static)

        # Show removal confirmation status first
        if self.pending_removal_index is not None:
            network_name = self.networks[self.pending_removal_index]
            status.update(f"❗ Remove '{network_name}'? Press 'c' to confirm, any other key to cancel")
        # Show reorder mode status if active
        elif self.reorder_mode:
            status.update("🔄 REORDER MODE: Use ↑↓ or k/j to move network • Press SPACE to exit")
        elif self.networks != self.original_networks:
            status.update("⚠️  Changes not saved! Press 's' to save or 'q' to quit without saving.")
        else:
            status.update("✅ No changes made. Press SPACE to reorder, 'r' to remove networks.")

    def watch_reorder_mode(self, new_value: bool) -> None:
        """Update UI when reorder mode changes."""
        self.update_status()

    def watch_pending_removal_index(self, new_value: int | None) -> None:
        """Update UI when pending removal changes."""
        self.update_status()

    def action_toggle_reorder_mode(self) -> None:
        """Toggle reorder mode on/off."""
        # Cancel any pending removal
        self.pending_removal_index = None
        self.reorder_mode = not self.reorder_mode

    def action_request_remove(self) -> None:
        """Request removal of the currently selected network."""
        list_view = self.query_one("#network-list", ListView)

        if list_view.index is None:
            return

        # Set pending removal
        self.pending_removal_index = list_view.index

    def on_key(self, event) -> None:
        """Handle key presses for mode-aware navigation."""
        # Handle confirmation for network removal
        if self.pending_removal_index is not None:
            if event.key == "c":
                # Confirm removal
                self._remove_network(self.pending_removal_index)
                self.pending_removal_index = None
            else:
                # Cancel removal
                self.pending_removal_index = None
            event.prevent_default()
            return

        # In reorder mode, arrow keys and k/j move the item
        if self.reorder_mode:
            if event.key in ("up", "k"):
                event.prevent_default()
                self.action_move_up()
            elif event.key in ("down", "j"):
                event.prevent_default()
                self.action_move_down()

    def action_move_up(self) -> None:
        """Move the selected network up in priority."""
        list_view = self.query_one("#network-list", ListView)

        if list_view.index is None or list_view.index == 0:
            return

        idx = list_view.index

        # Swap in networks list
        self.networks[idx], self.networks[idx - 1] = (
            self.networks[idx - 1],
            self.networks[idx]
        )

        # Rebuild list view
        self._rebuild_list()

        # Move selection up
        list_view.index = idx - 1
        self.update_status()

    def action_move_down(self) -> None:
        """Move the selected network down in priority."""
        list_view = self.query_one("#network-list", ListView)

        if list_view.index is None or list_view.index >= len(self.networks) - 1:
            return

        idx = list_view.index

        # Swap in networks list
        self.networks[idx], self.networks[idx + 1] = (
            self.networks[idx + 1],
            self.networks[idx]
        )

        # Rebuild list view
        self._rebuild_list()

        # Move selection down
        list_view.index = idx + 1
        self.update_status()

    def _rebuild_list(self) -> None:
        """Rebuild the list view with current network order."""
        list_view = self.query_one("#network-list", ListView)
        current_index = list_view.index or 0
        list_view.clear()

        for network in self.networks:
            list_view.append(NetworkListItem(network))

        # Restore selection, adjusting if we're past the end
        if self.networks:
            list_view.index = min(current_index, len(self.networks) - 1)

        # Ensure ListView stays focused so selection remains visible
        list_view.focus()

    def _remove_network(self, index: int) -> None:
        """Remove a network from the list."""
        if 0 <= index < len(self.networks):
            self.networks.pop(index)
            self._rebuild_list()
            self.update_status()

    def action_save(self) -> None:
        """Save the new network order and exit."""
        if self.networks == self.original_networks:
            self.exit(message="No changes to save.")
            return

        try:
            # Show saving status
            status = self.query_one("#status", Static)
            status.update("💾 Creating backup...")

            # Backup current network list before making changes
            backup_path = self._backup_networks()

            status.update(f"💾 Backup saved to: {backup_path}")
            time.sleep(1)

            # Apply the new priority order with progress updates
            self._apply_network_priority(status)
            self.exit(message="✅ WiFi network priorities updated successfully!")
        except Exception as e:
            self.exit(message=f"❌ Error saving priorities: {e}")

    def _backup_networks(self) -> str:
        """Backup current network list before making changes.

        Returns the path to the backup file.
        """
        # Create backups directory in user's home
        backup_dir = Path.home() / ".wifi-priority-backups"
        backup_dir.mkdir(exist_ok=True)

        # Create timestamped backup file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = backup_dir / f"networks_{timestamp}.txt"

        # Write network list to backup file
        with open(backup_file, "w") as f:
            f.write(f"# WiFi Priority Backup - {datetime.now()}\n")
            f.write(f"# Interface: {self.interface}\n")
            f.write(f"# Networks: {len(self.original_networks)}\n")
            f.write("#\n")
            for network in self.original_networks:
                f.write(f"{network}\n")

        # Keep only last 10 backups
        backups = sorted(backup_dir.glob("networks_*.txt"))
        for old_backup in backups[:-10]:
            old_backup.unlink()

        return str(backup_file)

    def _apply_network_priority(self, status: Static) -> None:
        """Apply the new network priority order using networksetup.

        Strategy: Remove all networks, then re-add them in reverse order.
        Networks are added at index 0, so the last one added becomes highest priority.
        """
        total = len(self.original_networks) + len(self.networks)
        current = 0

        # Remove all networks from the original list
        for network in self.original_networks:
            current += 1
            status.update(f"💾 Removing networks... ({current}/{total}) - {network}")
            result = subprocess.run(
                ["networksetup", "-removepreferredwirelessnetwork",
                 self.interface, network],
                capture_output=True,
                text=True
            )
            # Note: We ignore errors here as network might already be removed

        # Wait for macOS to process all removals
        status.update("⏳ Waiting for macOS to process changes...")
        time.sleep(0.5)

        # Add networks in reverse order (last added = highest priority)
        # Don't specify security type - macOS uses existing credentials from Keychain
        failed_networks = []
        for network in reversed(self.networks):
            current += 1
            status.update(f"💾 Adding networks... ({current}/{total}) - {network}")
            result = subprocess.run(
                ["networksetup", "-addpreferredwirelessnetworkatindex",
                 self.interface, network, "0"],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                # Log the failure but continue with other networks
                error_msg = result.stderr.strip() if result.stderr else result.stdout.strip()
                if not error_msg:
                    error_msg = f"Command failed with exit code {result.returncode}"
                failed_networks.append((network, error_msg))
                # Continue processing other networks
                continue

            # Small delay to ensure macOS processes each addition sequentially
            time.sleep(0.1)

        if failed_networks:
            failed_list = "\n".join([f"  • {net}: {err}" for net, err in failed_networks])
            status.update(f"⚠️ Some networks failed to save:\n{failed_list}")
            time.sleep(3)  # Give user time to read
            raise Exception(f"Failed to add {len(failed_networks)} network(s). See status for details.")

        status.update("✅ All networks saved!")


def detect_wifi_interface() -> str:
    """Detect the WiFi interface name."""
    result = subprocess.run(
        ["networksetup", "-listallhardwareports"],
        capture_output=True,
        text=True,
        check=True
    )

    lines = result.stdout.split("\n")
    for i, line in enumerate(lines):
        if "Wi-Fi" in line or "AirPort" in line:
            # Next line should have the device
            if i + 1 < len(lines) and lines[i + 1].startswith("Device:"):
                device = lines[i + 1].replace("Device:", "").strip()
                return device

    # Default fallback
    return "en0"


def get_preferred_networks(interface: str = "en0") -> List[str]:
    """Get the list of preferred WiFi networks in priority order."""
    result = subprocess.run(
        ["networksetup", "-listpreferredwirelessnetworks", interface],
        capture_output=True,
        text=True,
        check=True
    )

    lines = result.stdout.strip().split("\n")

    # Skip the header line
    if lines[0].startswith("Preferred networks"):
        lines = lines[1:]

    # Strip leading/trailing whitespace and tabs from each network name
    networks = [line.strip() for line in lines if line.strip()]

    return networks


def main():
    """Main entry point."""
    # Check if running with sudo
    if os.geteuid() != 0:
        print("❌ This application requires administrator privileges to modify network settings.")
        print("\nPlease run with sudo:")
        print(f"  sudo wifi-priority")
        print(f"\nOr if running directly:")
        print(f"  sudo python {sys.argv[0]}")
        sys.exit(1)

    try:
        # Detect WiFi interface
        interface = detect_wifi_interface()
        print(f"📡 Using WiFi interface: {interface}")

        # Get current network priority list
        networks = get_preferred_networks(interface)

        if not networks:
            print("\n❌ No preferred WiFi networks found.")
            print("\nThis means you don't have any saved networks in your preferred list.")
            print("\nTo add networks:")
            print("  1. Connect to WiFi networks you want to manage")
            print("  2. Make sure 'Remember this network' is checked when connecting")
            print("  3. Or add them manually in: System Settings → Network → WiFi → Advanced")
            print(f"\nYou can verify with: networksetup -listpreferredwirelessnetworks {interface}")
            sys.exit(1)

        print(f"✅ Found {len(networks)} preferred network(s)\n")

        # Run the TUI app
        app = WiFiReorderApp(networks, interface)
        result = app.run()

        # Print result message
        if result:
            print(result)

    except subprocess.CalledProcessError as e:
        print(f"❌ Error getting WiFi networks: {e}")
        print("Make sure you're running on macOS with WiFi enabled.")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\n👋 Cancelled.")
        sys.exit(0)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
