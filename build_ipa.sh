#!/bin/bash
set -e

VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
BUILD_NUM=$(grep "^version:" pubspec.yaml | cut -d'+' -f2)
ARCHIVE_PATH="build/ios/archive/djsports.xcarchive"
EXPORT_DIR="build/ios/ipa"

echo "Building IPA for djsports v${VERSION}+${BUILD_NUM}..."

flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist

IPA_SRC=$(find "$EXPORT_DIR" -name "*.ipa" | head -1)
if [ -n "$IPA_SRC" ]; then
  IPA_DST="${EXPORT_DIR}/djsports-${VERSION}.ipa"
  mv "$IPA_SRC" "$IPA_DST"
  echo "✓ Built: $IPA_DST"
else
  echo "✓ Archive at: $ARCHIVE_PATH"
  echo "  Open in Xcode Organizer to upload to App Store Connect."
fi
