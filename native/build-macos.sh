#!/usr/bin/env bash
# Build powertoy.app — a native macOS app (AppKit + WKWebView), no external toolchains.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
# version comes from the git tag at release time (POWERTOY_VERSION), or arg 1, else 'dev'
VER="${POWERTOY_VERSION:-${1:-0.0.0}}"
APP="build/powertoy.app"
BIN="$APP/Contents/MacOS/powertoy"
RES="$APP/Contents/Resources"

echo "▸ compiling…"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$RES"
swiftc -O Sources/main.swift -o "$BIN" -framework Cocoa -framework WebKit -framework CoreWLAN -framework CoreLocation

echo "▸ bundling the app…"
cp "$ROOT/index.html" "$RES/index.html"
cp "$ROOT/manifest.webmanifest" "$ROOT/icon-192.png" "$ROOT/icon-512.png" "$ROOT/icon-maskable-512.png" "$RES/" 2>/dev/null || true

echo "▸ icon…"
ICONSET="$(mktemp -d)/powertoy.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ROOT/icon-512.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d "$ROOT/icon-512.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RES/powertoy.icns" 2>/dev/null && rm -rf "$(dirname "$ICONSET")"

echo "▸ Info.plist…"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>powertoy</string>
  <key>CFBundleDisplayName</key><string>powertoy</string>
  <key>CFBundleIdentifier</key><string>dev.powertoy.app</string>
  <key>CFBundleVersion</key><string>${VER}</string>
  <key>CFBundleShortVersionString</key><string>${VER}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>powertoy</string>
  <key>CFBundleIconFile</key><string>powertoy</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSLocationUsageDescription</key><string>powertoy reads WiFi signal (RSSI, SSID, channel), which macOS gates behind Location access.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>powertoy reads WiFi signal (RSSI, SSID, channel), which macOS gates behind Location access.</string>
</dict></plist>
PLIST

# Sign with a Developer ID identity if one is provided (CI release path), so the app
# can be notarized and runs on download without Gatekeeper warnings. Otherwise ad-hoc
# sign — fine for running locally, but not for distribution.
if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "▸ signing with Developer ID (hardened runtime): $SIGN_IDENTITY"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BIN"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  echo "▸ ad-hoc signing (unsigned local build — distribute only after notarizing)"
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
fi

echo "✓ built $APP"
echo "  run:  open $(dirname "$0")/$APP"
echo "  (first launch: right-click → Open, since it isn't notarized)"
