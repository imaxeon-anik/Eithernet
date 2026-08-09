#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Eithernet"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Optional overrides for CI / releases (e.g. VERSION=1.0.0 BUILD=42)
VERSION="${VERSION:-1.0.0}"
VERSION="${VERSION#v}"
BUILD="${BUILD:-1}"

cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"

ICON_SRC="$ROOT_DIR/Resources/AppIcon.icns"
if [[ ! -f "$ICON_SRC" ]]; then
  echo "Missing app icon: $ICON_SRC" >&2
  exit 1
fi

BIN_DIR="$(dirname "$BIN_PATH")"
RESOURCE_BUNDLE="$BIN_DIR/Eithernet_Eithernet.bundle"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "$ICON_SRC" "$RESOURCES_DIR/AppIcon.icns"

# SPM embeds menu-bar icon assets in a resource bundle beside the executable.
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$MACOS_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Eithernet</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.eithernet.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Eithernet</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${BUILD}</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Eithernet needs Location access to scan and list nearby Wi‑Fi networks.</string>
	<key>NSLocationUsageDescription</key>
	<string>Eithernet needs Location access to scan and list nearby Wi‑Fi networks.</string>
</dict>
</plist>
EOF

echo "Built $APP_DIR (version $VERSION, build $BUILD)"
echo "Open with: open \"$APP_DIR\""
