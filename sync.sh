#!/usr/bin/env bash
# Propagate a change in index.html to every package that bundles a snapshot of it:
# the Chrome extension and the native macOS app. The PWA needs nothing — it serves
# index.html directly and auto-updates when online.
set -euo pipefail
cd "$(dirname "$0")"

VER="$(cat VERSION 2>/dev/null || echo 1.0.0)"
echo "▸ syncing app into the Chrome extension (version $VER)…"
cp index.html manifest.webmanifest icon-192.png icon-512.png icon-maskable-512.png extension/
# stamp the extension version from the single source of truth (VERSION)
MAN=extension/manifest.json
perl -i -pe "s/\"version\": *\"[0-9.]+\"/\"version\": \"$VER\"/" "$MAN"

echo "▸ rebuilding the native macOS app…"
if command -v swiftc >/dev/null 2>&1; then
  ./native/build-macos.sh >/dev/null && echo "  native/build/powertoy.app rebuilt"
else
  echo "  (swiftc not found — skipping native build)"
fi

echo "✓ synced. PWA users get the update automatically on next load."
echo "  Extension: reload at chrome://extensions (dev) or publish the new version."
echo "  Native:    replace your installed copy with native/build/powertoy.app."
