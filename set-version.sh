#!/usr/bin/env bash
# Bump the version in the committed files so the repo stays truthful.
# Run this in your feature branch, commit the result, and include it in your PR.
# On release, the CI workflow re-stamps from the git tag and verifies tag == VERSION,
# so this is what keeps the two in lockstep.
#
#   ./set-version.sh 1.2.0     # set a new version
#   ./set-version.sh           # re-stamp the current VERSION
#
# Does NOT touch git and does NOT build the native app (CI does that on the tag).
set -euo pipefail
cd "$(dirname "$0")"

[ $# -ge 1 ] && printf '%s\n' "$1" > VERSION
VER="$(cat VERSION)"
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ VERSION must be x.y.z (got '$VER')"; exit 1; }

# app badge
perl -i -pe "s/const APP_VERSION = '[^']*'/const APP_VERSION = '$VER'/" index.html
# extension copy + manifest version
cp index.html manifest.webmanifest icon-192.png icon-512.png icon-maskable-512.png extension/
perl -i -pe "s/\"version\": *\"[0-9.]+\"/\"version\": \"$VER\"/" extension/manifest.json

# verify the committed surfaces agree (native plist is derived from VERSION at build time)
APP_V=$(perl -ne "print \$1 if /const APP_VERSION = '([^']*)'/" index.html)
EXT_V=$(perl -ne 'print $1 if /"version":\s*"([0-9.]+)"/' extension/manifest.json | head -1)
echo "VERSION=$VER  app=$APP_V  extension=$EXT_V  (native: built from VERSION in CI)"
[ "$APP_V" = "$VER" ] && [ "$EXT_V" = "$VER" ] || { echo "✗ mismatch"; exit 1; }
echo "✓ committed files consistent"
echo
echo "Next:"
echo "  git checkout -b release-$VER && git add -A && git commit -m \"release v$VER\""
echo "  open a PR → merge to main → then tag it:"
echo "  git checkout main && git pull && git tag v$VER && git push origin v$VER"
echo "  → CI publishes the macOS release and deploys Pages, both at v$VER."
