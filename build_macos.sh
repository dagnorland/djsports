#!/bin/bash
# Builds a macOS installer package for Mac App Store submission.
#
# Usage:
#   ./build_macos.sh         # build only
#
# Prerequisites:
#   1. Xcode: sign in with your Apple ID (Xcode > Settings > Accounts)
#   2. macos/ExportOptions.plist configured with your Team ID
#   3. macOS platform added to the app in App Store Connect
#      (https://appstoreconnect.apple.com)
#
# Output:
#   build/macos/pkg/djsports-<version>.pkg

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# Use the project's FVM Flutter SDK when available
if command -v fvm >/dev/null 2>&1; then
  FLUTTER="fvm flutter"
else
  FLUTTER="flutter"
fi

# ── Versions ──────────────────────────────────────────────────────────────────
PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VERSION_NAME=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f2)

ARCHIVE_PATH="build/macos/archive/djsports.xcarchive"
EXPORT_DIR="build/macos/pkg"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  djSports macOS — Mac App Store build                       ║"
echo "║  Version: ${VERSION_NAME}  Build: ${BUILD_NUMBER}$(printf '%*s' $((37 - ${#VERSION_NAME} - ${#BUILD_NUMBER})) '')║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Flutter build macos ───────────────────────────────────────────────
# Compiles the Dart code and writes the version into the Xcode config
echo "▶ Step 1/3 — flutter build macos --release"
$FLUTTER build macos --release \
  --build-name="$VERSION_NAME" \
  --build-number="$BUILD_NUMBER"
echo ""

# ── Step 2: Xcode archive ─────────────────────────────────────────────────────
echo "▶ Step 2/3 — xcodebuild archive"
archive() {
  rm -rf "$ARCHIVE_PATH"
  xcodebuild archive \
    -workspace macos/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -quiet
}
# Xcode 27 sometimes compiles gRPC-Core before abseil's headers are
# copied ('absl/status/statusor.h' file not found); a second run passes
if ! archive; then
  echo ""
  echo "⚠ Archive failed — retrying once (known flaky Pods build order)"
  echo ""
  archive
fi
echo ""

# ── Step 3: Export signed .pkg ────────────────────────────────────────────────
echo "▶ Step 3/3 — xcodebuild -exportArchive"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist macos/ExportOptions.plist \
  -allowProvisioningUpdates \
  -quiet
echo ""

RELEASE_DIR="/Users/dagnorland/Library/Mobile Documents/com~apple~CloudDocs/djsports/release"

PKG_SRC=$(find "$EXPORT_DIR" -name "*.pkg" 2>/dev/null | head -1)
if [ -n "${PKG_SRC:-}" ]; then
  PKG_DST="${EXPORT_DIR}/djsports-${VERSION_NAME}.pkg"
  mv "$PKG_SRC" "$PKG_DST"
  echo "✓ Package ready: $PKG_DST"
  echo "  (Archive:       $ARCHIVE_PATH)"
  mkdir -p "$RELEASE_DIR"
  cp "$PKG_DST" "$RELEASE_DIR/"
  echo "✓ Copied to:     $RELEASE_DIR/djsports-${VERSION_NAME}.pkg"
else
  echo "✓ Archive at: $ARCHIVE_PATH"
  echo "  Open in Xcode Organizer to upload to App Store Connect."
fi
echo ""

echo "Next steps:"
echo "  Option A — Transporter (easiest):"
echo "    Open Transporter.app and drag in the .pkg from $EXPORT_DIR"
echo ""
echo "  Option B — Xcode Organizer:"
echo "    Open Xcode > Window > Organizer and distribute the archive."
echo ""
echo "  App Store Connect: https://appstoreconnect.apple.com"
