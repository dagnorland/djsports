#!/bin/bash
# Builds a release APK for Android.
#
# Usage:
#   ./build_apk.sh
#
# Output:
#   build/app/outputs/flutter-apk/djsports-<version>.apk

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# ── Versions ──────────────────────────────────────────────────────────────────
PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VERSION_NAME=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$PUBSPEC_VERSION" | cut -d'+' -f2)

OUTPUT_DIR="build/app/outputs/flutter-apk"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  djSports Android — APK build                               ║"
echo "║  Version: ${VERSION_NAME}  Build: ${BUILD_NUMBER}$(printf '%*s' $((37 - ${#VERSION_NAME} - ${#BUILD_NUMBER})) '')║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Flutter build apk ─────────────────────────────────────────────────
echo "▶ Step 1/1 — flutter build apk --release"
flutter build apk --release \
  --build-name="$VERSION_NAME" \
  --build-number="$BUILD_NUMBER"
echo ""

RELEASE_DIR="/Users/dagnorland/Library/Mobile Documents/com~apple~CloudDocs/djsports/release"

SRC="${OUTPUT_DIR}/app-release.apk"
DST="${OUTPUT_DIR}/djsports-${VERSION_NAME}.apk"
mv "$SRC" "$DST"
echo "✓ Package ready: $DST"
mkdir -p "$RELEASE_DIR"
cp "$DST" "$RELEASE_DIR/"
echo "✓ Copied to:     $RELEASE_DIR/djsports-${VERSION_NAME}.apk"
