#!/bin/bash
set -e

flutter build apk --release

VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
SRC="build/app/outputs/flutter-apk/app-release.apk"
DST="build/app/outputs/flutter-apk/djsports-${VERSION}.apk"

mv "$SRC" "$DST"
echo "✓ Built: $DST"
