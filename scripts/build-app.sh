#!/usr/bin/env bash
# Builds 一隅.app (release, ad hoc signed) into build/.
#   ./scripts/build-app.sh            build only
#   ./scripts/build-app.sh --install  also replace /Applications/一隅.app and launch it
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="一隅"
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw Resources/Info.plist)"
BUILD_DIR="build"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

make_icon() {
  local iconset="$BUILD_DIR/AppIcon.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"
  swift scripts/make-icon.swift "$BUILD_DIR/icon-1024.png"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$BUILD_DIR/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    local double=$((size * 2))
    sips -z "$double" "$double" "$BUILD_DIR/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$BUILD_DIR/AppIcon.icns"
}

mkdir -p "$BUILD_DIR"
echo "==> Building release binary"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

if [ ! -f "$BUILD_DIR/AppIcon.icns" ] || [ scripts/make-icon.swift -nt "$BUILD_DIR/AppIcon.icns" ]; then
  echo "==> Drawing app icon"
  make_icon
fi

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/Yiyu" "$BUNDLE/Contents/MacOS/Yiyu"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier "$BUNDLE_ID" "$BUNDLE"
codesign --verify --strict "$BUNDLE"

if [ "${1:-}" != "--install" ]; then
  echo "Built $BUNDLE"
  exit 0
fi

TARGET="$INSTALL_DIR/$APP_NAME.app"
if pgrep -xq Yiyu; then
  echo "==> Quitting the running copy (it saves on quit)"
  pkill -TERM -x Yiyu || true
  for _ in $(seq 1 50); do
    pgrep -xq Yiyu || break
    sleep 0.1
  done
fi

echo "==> Installing to $TARGET"
rm -rf "$TARGET"
ditto "$BUNDLE" "$TARGET"
open "$TARGET"
echo "Installed and launched $TARGET"
