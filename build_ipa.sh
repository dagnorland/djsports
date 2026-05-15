#!/bin/bash
# Builds an iOS IPA for App Store submission.
#
# Usage:
#   ./build_ipa.sh           # build only
#
# Prerequisites:
#   1. Xcode: sign in with your Apple ID (Xcode > Settings > Accounts)
#   2. ios/ExportOptions.plist configured with your Team ID
#   3. App record created in App Store Connect (https://appstoreconnect.apple.com)
#
# Output:
#   build/ios/ipa/djsports-<version>.ipa

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# ── Versions ──────────────────────────────────────────────────────────────────
PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VERSION_NAME=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f2)

ARCHIVE_PATH="build/ios/archive/djsports.xcarchive"
EXPORT_DIR="build/ios/ipa"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  djSports iOS — App Store build                             ║"
echo "║  Version: ${VERSION_NAME}  Build: ${BUILD_NUMBER}$(printf '%*s' $((37 - ${#VERSION_NAME} - ${#BUILD_NUMBER})) '')║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Flutter build ipa ─────────────────────────────────────────────────
echo "▶ Step 1/1 — flutter build ipa --release"
flutter build ipa --release \
  --build-name="$VERSION_NAME" \
  --build-number="$BUILD_NUMBER" \
  --export-options-plist=ios/ExportOptions.plist
echo ""

RELEASE_DIR="/Users/dagnorland/Library/Mobile Documents/com~apple~CloudDocs/djsports/release"

IPA_SRC=$(find "$EXPORT_DIR" -name "*.ipa" 2>/dev/null | head -1)
if [ -n "${IPA_SRC:-}" ]; then
  IPA_DST="${EXPORT_DIR}/djsports-${VERSION_NAME}.ipa"
  mv "$IPA_SRC" "$IPA_DST"
  echo "✓ Package ready: $IPA_DST"
  echo "  (Archive:       $ARCHIVE_PATH)"
  mkdir -p "$RELEASE_DIR"
  cp "$IPA_DST" "$RELEASE_DIR/"
  echo "✓ Copied to:     $RELEASE_DIR/djsports-${VERSION_NAME}.ipa"
else
  echo "✓ Archive at: $ARCHIVE_PATH"
  echo "  Open in Xcode Organizer to upload to App Store Connect."
fi
echo ""

echo "Next steps:"
echo "  Option A — Transporter (easiest):"
echo "    Open Transporter.app and drag in the .ipa from $EXPORT_DIR"
echo ""
echo "  Option B — Xcode Organizer:"
echo "    Open Xcode > Window > Organizer and distribute the archive."
echo ""
echo "  App Store Connect: https://appstoreconnect.apple.com"
