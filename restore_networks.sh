#!/bin/bash
# Emergency network restore script
# Restores networks from backup_networks.txt

INTERFACE="en0"
BACKUP_FILE="backup_networks.txt"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "🔄 Restoring networks to $INTERFACE..."
echo ""

count=0
failed=0

# Read networks in reverse order (last added = highest priority)
while IFS= read -r network || [ -n "$network" ]; do
    if [ -z "$network" ]; then
        continue
    fi

    count=$((count + 1))
    echo "[$count] Adding: $network"

    # Pass empty string as security type to let macOS auto-detect from Keychain
    if sudo networksetup -addpreferredwirelessnetworkatindex "$INTERFACE" "$network" 0 "" 2>/dev/null; then
        echo "  ✅ Added"
    else
        echo "  ⚠️  Failed"
        failed=$((failed + 1))
    fi

    sleep 0.1
done < <(tail -r "$BACKUP_FILE")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Restore complete!"
echo "   Added: $((count - failed)) networks"
echo "   Failed: $failed networks"
echo ""
echo "Verify with: networksetup -listpreferredwirelessnetworks $INTERFACE"
