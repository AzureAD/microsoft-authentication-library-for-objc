#!/bin/bash
#
# Builds a local MSAL.xcframework from source into ./local-xcframework/MSAL.xcframework
# so that the root Swift package (which references it via a local binaryTarget) builds
# without depending on a published release zip.
#
# The local-xcframework/ folder is intentionally git-ignored. Run this script once after
# cloning (or whenever IdentityCore/MSAL source changes) to regenerate the framework.
#
# Usage:
#   ./build-local-xcframework.sh
#
set -euo pipefail

# Always operate from the repository root (this script's directory), regardless of the
# caller's current working directory.
cd "$(dirname "${BASH_SOURCE[0]}")"

WORKSPACE="MSAL.xcworkspace"
OUTPUT_DIR="local-xcframework"
ARCHIVE_DIR="$(mktemp -d)"
trap 'rm -rf "$ARCHIVE_DIR"' EXIT

IOS_SCHEME="MSAL (iOS Framework)"
MAC_SCHEME="MSAL (Mac Framework)"

echo "==> Ensuring submodules are initialized"
git submodule update --init --recursive

archive()
{
    local scheme="$1"
    local destination="$2"
    local archive_path="$3"

    echo "==> Archiving '$scheme' for $destination"
    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$scheme" \
        -destination "$destination" \
        -archivePath "$archive_path" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        | xcpretty || xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$scheme" \
        -destination "$destination" \
        -archivePath "$archive_path" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES
}

archive "$IOS_SCHEME" "generic/platform=iOS"           "$ARCHIVE_DIR/ios-device"
archive "$IOS_SCHEME" "generic/platform=iOS Simulator"  "$ARCHIVE_DIR/ios-simulator"
archive "$MAC_SCHEME" "generic/platform=macOS"          "$ARCHIVE_DIR/macos"

echo "==> Creating xcframework"
rm -rf "$OUTPUT_DIR/MSAL.xcframework"
mkdir -p "$OUTPUT_DIR"

xcodebuild -create-xcframework \
    -framework "$ARCHIVE_DIR/ios-device.xcarchive/Products/Library/Frameworks/MSAL.framework" \
    -framework "$ARCHIVE_DIR/ios-simulator.xcarchive/Products/Library/Frameworks/MSAL.framework" \
    -framework "$ARCHIVE_DIR/macos.xcarchive/Products/Library/Frameworks/MSAL.framework" \
    -output "$OUTPUT_DIR/MSAL.xcframework"

echo "==> Done: $OUTPUT_DIR/MSAL.xcframework"
