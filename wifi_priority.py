#!/usr/bin/env python3
"""
Interactive TUI for reordering macOS WiFi network priorities.
"""

import os
import subprocess
import sys
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

    /* Selected item - always visible whether focused or not */
    ListItem.-active {
        background: $accent;
        color: $text;
    }

    /* Make selection even more visible when ListView is focused */
    ListView:focus ListItem.-active {
        background: $accent;
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
            # Apply the new priority order
            self._apply_network_priority()
            self.exit(message="✅ WiFi network priorities updated successfully!")
        except Exception as e:
            self.exit(message=f"❌ Error saving priorities: {e}")

    def _apply_network_priority(self) -> None:
        """Apply the new network priority order using networksetup.

        Strategy: Remove all networks, then re-add them in reverse order.
        Networks are added at index 0, so the last one added becomes highest priority.
        """
        # Remove all networks from the original list
        for network in self.original_networks:
            result = subprocess.run(
                ["networksetup", "-removepreferredwirelessnetwork",
                 self.interface, network],
                capture_output=True,
                text=True
            )
            # Note: We ignore errors here as network might already be removed

        # Add networks in reverse order (last added = highest priority)
        # Don't specify security type - macOS uses existing credentials from Keychain
        for network in reversed(self.networks):
            result = subprocess.run(
                ["networksetup", "-addpreferredwirelessnetworkatindex",
                 self.interface, network, "0"],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                raise Exception(f"Failed to add network '{network}': {error_msg}")


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
        # Get current network priority list
        networks = get_preferred_networks()

        if not networks:
            print("❌ No preferred WiFi networks found.")
            print("Connect to some WiFi networks first, then try again.")
            sys.exit(1)

        # Run the TUI app
        app = WiFiReorderApp(networks)
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
