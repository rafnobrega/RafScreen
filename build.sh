#!/bin/bash
set -e

APP_NAME="RafScreen"
BUILD_DIR="$(dirname "$0")/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
SOURCES_DIR="$(dirname "$0")/Sources"

echo "Building ${APP_NAME}..."

# Clean previous build
rm -rf "${BUILD_DIR}"

# Create .app bundle structure
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy Info.plist and resources
cp "$(dirname "$0")/Info.plist" "${CONTENTS}/Info.plist"
cp "$(dirname "$0")/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"

# Compile all Swift source files
echo "Compiling Swift sources..."
swiftc \
    -o "${MACOS}/${APP_NAME}" \
    -target arm64-apple-macos13.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework AppKit \
    -framework AVFoundation \
    -framework CoreMedia \
    -framework CoreMediaIO \
    -framework QuartzCore \
    "${SOURCES_DIR}/DeviceModels.swift" \
    "${SOURCES_DIR}/DeviceCaptureManager.swift" \
    "${SOURCES_DIR}/DeviceBezelView.swift" \
    "${SOURCES_DIR}/MainWindowController.swift" \
    "${SOURCES_DIR}/AppDelegate.swift" \
    "${SOURCES_DIR}/main.swift"

# Sign the app (ad-hoc for local use)
echo "Signing..."
codesign --force --sign - --entitlements "$(dirname "$0")/RafScreen.entitlements" "${APP_BUNDLE}"

echo ""
echo "Build successful! App bundle at: ${APP_BUNDLE}"
echo "Run with: open \"${APP_BUNDLE}\""
