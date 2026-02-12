#!/bin/bash
#
# build.sh - Build WiFi Priority SwiftUI app
#
# This script compiles the SwiftUI app into a macOS .app bundle
#

set -e

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
    WiFiPrioritySwiftUI/WiFiPriorityApp.swift \
    WiFiPrioritySwiftUI/ContentView.swift \
    WiFiPrioritySwiftUI/NetworkManager.swift \
    -framework SwiftUI \
    -framework AppKit \
    -target arm64-apple-macos13.0

echo "✅ Build complete!"
echo "📍 App location: build/WiFiPrioritySwiftUI.app"
echo ""
echo "To run:"
echo "  open build/WiFiPrioritySwiftUI.app"
