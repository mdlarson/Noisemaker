#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/.derived-universal"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Noise Studio"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/Noise-Studio-macOS.zip"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$ROOT_DIR/NoisemakerNative.xcodeproj" \
  -scheme NoisemakerNative \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS='arm64 x86_64' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

cp -R "$APP_PATH" "$DIST_DIR/"

ditto -c -k --sequesterRsrc --keepParent \
  "$DIST_DIR/$APP_NAME.app" \
  "$ZIP_PATH"

echo "Created:"
echo "  $DIST_DIR/$APP_NAME.app"
echo "  $ZIP_PATH"
