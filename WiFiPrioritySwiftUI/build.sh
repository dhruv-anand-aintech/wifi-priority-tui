#!/bin/bash
#
# build.sh - Build WiFi Priority SwiftUI app
#
# Usage:
#   ./build.sh                    # Ad-hoc signing (development only)
#   ./build.sh "Developer ID"     # Developer ID signing (for distribution)
#
# To find your Developer ID:
#   security find-identity -v -p codesigning | grep "Developer ID"
#

set -e

SIGNING_IDENTITY="${1:--}"  # Default to ad-hoc signing

echo "🔨 Building WiFi Priority SwiftUI..."

# Create build directories
rm -rf build
mkdir -p build/WiFiPrioritySwiftUI.app/Contents/MacOS
mkdir -p build/WiFiPrioritySwiftUI.app/Contents/Resources

# Copy Info.plist
cp Info.plist build/WiFiPrioritySwiftUI.app/Contents/Info.plist

# Compile Swift files
echo "📦 Compiling Swift files..."
swiftc -o build/WiFiPrioritySwiftUI.app/Contents/MacOS/WiFiPrioritySwiftUI \
    WiFiPriorityApp.swift \
    ContentView.swift \
    NetworkManager.swift \
    -framework SwiftUI \
    -framework AppKit \
    -target arm64-apple-macos13.0

# Sign the app
echo "🔏 Signing app with: $SIGNING_IDENTITY"
if [ "$SIGNING_IDENTITY" = "-" ]; then
    # Ad-hoc signing (development)
    codesign --force --deep --sign - build/WiFiPrioritySwiftUI.app 2>/dev/null || echo "⚠️  Code signing failed"
else
    # Developer ID signing with timestamp (for distribution)
    codesign --force --deep --sign "$SIGNING_IDENTITY" \
        --timestamp \
        --options runtime \
        build/WiFiPrioritySwiftUI.app 2>/dev/null || echo "⚠️  Code signing failed"
fi

echo "✅ Build complete!"
echo "📍 App location: build/WiFiPrioritySwiftUI.app"
echo ""
if [ "$SIGNING_IDENTITY" = "-" ]; then
    echo "⚠️  Ad-hoc signed (unsigned). Users will see Gatekeeper warning."
    echo "   To remove warning: xattr -d com.apple.quarantine build/WiFiPrioritySwiftUI.app"
else
    echo "✅ Developer ID signed! Gatekeeper will trust this app."
fi
echo ""
echo "To run:"
echo "  open build/WiFiPrioritySwiftUI.app"
