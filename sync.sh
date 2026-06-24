#!/usr/bin/env bash
# Local helper: copy the current app into the Chrome extension and rebuild the native
# app, so you can test those two channels locally. Versions are stamped from the git
# tag by CI at release time — this is just for local testing, so it leaves a 0.0.0
# placeholder. The PWA needs nothing; it serves index.html directly.
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ copying app into the Chrome extension…"
cp index.html manifest.webmanifest icon-192.png icon-512.png icon-maskable-512.png extension/

echo "▸ rebuilding the native macOS app…"
if command -v swiftc >/dev/null 2>&1; then
  ./native/build-macos.sh >/dev/null && echo "  native/build/powertoy.app rebuilt"
else
  echo "  (swiftc not found — skipping native build)"
fi

echo "✓ done (local test builds; release versions are set from the git tag in CI)."
