#!/bin/bash
# build.sh - Build script for macSA (Grand Theft Auto: San Andreas for Apple Silicon macOS)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building macSA..."

# 1. Compile native launcher
echo "--> Compiling native launcher (macSA)..."
clang -O3 -arch arm64 -Wall -Wextra "$SCRIPT_DIR/macSA.c" -o "$SCRIPT_DIR/macSA"

# 2. Prepare bundle skeleton
APP_DIR="$ROOT_DIR/macSA.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/GameData"
mkdir -p "$APP_DIR/Contents/Frameworks"

# 3. Copy launcher and runtime
echo "--> Installing binaries..."
cp "$SCRIPT_DIR/macSA" "$APP_DIR/Contents/MacOS/macSA"

# Use cached or downloaded Saif runtime
SAIF_BIN="/tmp/saif_inspect/Saif.app/Contents/MacOS/Saif"
if [ ! -f "$SAIF_BIN" ]; then
    echo "Downloading Saif runtime..."
    mkdir -p /tmp/saif_download
    curl -fsSL https://github.com/saif-runtime/saif-runtime/releases/download/3.0.0/Saif.zip -o /tmp/saif_download/Saif.zip
    unzip -q /tmp/saif_download/Saif.zip -d /tmp/saif_download/
    SAIF_BIN="/tmp/saif_download/Saif.app/Contents/MacOS/Saif"
fi

cp "$SAIF_BIN" "$APP_DIR/Contents/MacOS/SaifRuntime"
chmod +x "$APP_DIR/Contents/MacOS/macSA" "$APP_DIR/Contents/MacOS/SaifRuntime"

# 4. Copy Frameworks
if [ -d "/tmp/saif_inspect/Saif.app/Contents/Frameworks/Sparkle.framework" ]; then
    cp -R "/tmp/saif_inspect/Saif.app/Contents/Frameworks/Sparkle.framework" "$APP_DIR/Contents/Frameworks/"
elif [ -d "/tmp/saif_download/Saif.app/Contents/Frameworks/Sparkle.framework" ]; then
    cp -R "/tmp/saif_download/Saif.app/Contents/Frameworks/Sparkle.framework" "$APP_DIR/Contents/Frameworks/"
fi

# 5. Build authentic icon if not present
ICON_PATH="$APP_DIR/Contents/Resources/macSA.icns"
if [ -f "/tmp/macSA.icns" ]; then
    cp "/tmp/macSA.icns" "$ICON_PATH"
else
    echo "--> Generating macSA.icns from vector logo..."
    TMP_ICONSET="$(mktemp -d)/macSA.iconset"
    mkdir -p "$TMP_ICONSET"
    qlmanage -t -s 1024 -o /tmp "$SCRIPT_DIR/gta_sa_logo.svg" >/dev/null 2>&1 || true
    LOGO_PNG="/tmp/gta_sa_logo.svg.png"
    sips -z 16 16     "$LOGO_PNG" --out "$TMP_ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32     "$LOGO_PNG" --out "$TMP_ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "$LOGO_PNG" --out "$TMP_ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64     "$LOGO_PNG" --out "$TMP_ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "$LOGO_PNG" --out "$TMP_ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256   "$LOGO_PNG" --out "$TMP_ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "$LOGO_PNG" --out "$TMP_ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512   "$LOGO_PNG" --out "$TMP_ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "$LOGO_PNG" --out "$TMP_ICONSET/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$LOGO_PNG" --out "$TMP_ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$TMP_ICONSET" -o "$ICON_PATH"
    rm -rf "$(dirname "$TMP_ICONSET")"
fi

# 6. Create Info.plist
cat << 'PLIST' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Grand Theft Auto San Andreas</string>
	<key>CFBundleExecutable</key>
	<string>macSA</string>
	<key>CFBundleIconFile</key>
	<string>macSA</string>
	<key>CFBundleIdentifier</key>
	<string>com.github.gtamac.macSA</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>macSA</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>3.0.0</string>
	<key>CFBundleVersion</key>
	<string>3.0.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.games</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
</dict>
</plist>
PLIST

# 7. Create PkgInfo
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 8. Sign the bundle ad-hoc
echo "--> Signing macSA.app bundle..."
xattr -cr "$APP_DIR" 2>/dev/null || true
if [ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]; then
    codesign --force --sign - "$APP_DIR/Contents/Frameworks/Sparkle.framework" 2>/dev/null || true
fi
codesign --force --sign - "$APP_DIR/Contents/MacOS/SaifRuntime"
codesign --force --sign - "$APP_DIR/Contents/MacOS/macSA"
codesign --force --sign - "$APP_DIR"

# 9. Compute version.sha
echo "--> Computing version.sha..."
shasum -a 256 "$APP_DIR/Contents/MacOS/SaifRuntime" | awk '{print $1}' > "$ROOT_DIR/version.sha"
cp "$ROOT_DIR/version.sha" "$APP_DIR/Contents/Resources/version.sha"

# 10. Package archives
echo "--> Packaging release archives..."
cd "$ROOT_DIR"
rm -f macSA-macos-arm64.tar.gz macSA-macos-arm64.zip
COPYFILE_DISABLE=1 tar -czf macSA-macos-arm64.tar.gz macSA.app
zip -q -r macSA-macos-arm64.zip macSA.app -x "*.DS_Store"

echo "✔ Build complete!"
ls -lh macSA-macos-arm64.tar.gz macSA-macos-arm64.zip version.sha
