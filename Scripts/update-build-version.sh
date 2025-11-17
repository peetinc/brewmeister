#!/bin/bash
# Update CFBundleVersion in Info.plist with current UTC timestamp
# Format: YY.MM.DD.HHmm (e.g., 25.11.17.0759)

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLIST_FILE="$PROJECT_ROOT/Sources/Resources/Info.plist"

# Check if Info.plist exists
if [ ! -f "$PLIST_FILE" ]; then
    echo "Error: Info.plist not found at $PLIST_FILE"
    exit 1
fi

# Generate build version in format: YY.MM.DD.HHmm
BUILD_VERSION=$(date -u '+%y.%m.%d.%H%M')

echo "Updating CFBundleVersion to: $BUILD_VERSION"

# Use PlistBuddy to update the version (macOS built-in tool)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_VERSION" "$PLIST_FILE"

echo "✓ CFBundleVersion updated to $BUILD_VERSION in Info.plist"
