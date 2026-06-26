# Packaging powertoy

powertoy is one self-contained `index.html`. It runs four ways, from "double-click a file"
to "installed native app." All are fully offline.

| Path | Build step | Offline | Best for |
|------|-----------|---------|----------|
| **Single file** | none | ✅ (`file://`) | quick use, USB stick, email |
| **PWA** | none (just serve) | ✅ (service worker) | installable browser app, auto-updates |
| **Chrome extension** | none (load unpacked) | ✅ (bundled) | one-click from the toolbar |
| **Native macOS app** | `native/build-macos.sh` | ✅ (bundled) | a real `.app` in your Dock |

---

## 1. Single file

```bash
open index.html        # macOS
xdg-open index.html    # Linux
```

Works from `file://` with zero network calls. WebCrypto-backed tools (AES, HMAC, TOTP,
JWT signer) need a "secure context" — `file://` qualifies in Chrome and Safari. If a
browser ever blocks them, use the PWA path below.

## Deploy to GitHub Pages (CI/CD: dev → PR → main → tag)

The site, the macOS release, and the version are all driven by **git tags through GitHub
Actions** — no manual deploys. `.github/workflows/release.yml` runs on any `vX.Y.Z` tag and
does two things at once: deploys the site to Pages and publishes the macOS release.

**One-time setup**

```bash
git init && git add -A && git commit -m "powertoy"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

In the repo settings:
- **Settings → Pages → Build and deployment → Source → GitHub Actions.** (Not "branch" —
  the workflow deploys.)
- **Settings → Branches → add a rule for `main` → require a pull request before merging.**
  This enforces the dev → PR → main flow.

Your site will go live at `https://<you>.github.io/<repo>/` after the first tag. It's HTTPS,
so the PWA/service worker and WebCrypto tools all work. The page's **version badge** and
**"⤓ macOS app"** button light up automatically — the repo is derived from the Pages URL,
so the button points at `…/releases/latest/download/powertoy-macos.zip` (always the newest),
with no hardcoding. (Locally the button is hidden since there's no repo.)

**The everyday flow**

The git tag is the only version. There's no version file to bump and nothing to stamp by
hand — develop, merge, tag.

```bash
# 1. develop on a branch
git checkout -b my-change
#    …edit index.html…

# 2. PR → review → merge to main  (normal GitHub flow)

# 3. release: tag main and push the tag — that's the whole release
git checkout main && git pull
git tag v1.3.0 && git push origin v1.3.0
```

Pushing the tag triggers the workflow:
1. **version** — reads the version from the tag (`v1.3.0` → `1.3.0`), rejecting malformed tags.
2. **deploy-pages** — stamps that version into `index.html` and deploys the site.
3. **release** — builds `powertoy.app` and the Chrome extension, stamps both with the
   version, and publishes a GitHub Release with `powertoy-macos.zip` + `powertoy-extension.zip`.

The live page's badge and the downloadable artifacts therefore always match the tag.

> Prefer the GitHub UI? Creating a **Release** with tag `v1.3.0` does the same thing — it
> pushes the tag, which triggers the workflow. No other steps.

**Version consistency** is automatic because there is only one source: the tag. In the repo,
`APP_VERSION` stays `'dev'` and the extension manifest stays `0.0.0`; CI replaces both from
the tag at release time, so the repo can never disagree with a release. (Note: the `CACHE`
value in `sw.js` is a *separate* service-worker cache version — bump it only when you change
`sw.js` itself.)

## 2. PWA (installable, offline)

Serve the folder over http(s) — any static host or:

```bash
python3 -m http.server 8000
# open http://localhost:8000 → browser menu → "Install powertoy"
```

`sw.js` precaches the whole app shell on first load (`index.html`, manifest, icons),
so it then works with the network fully off. To ship an update, bump `CACHE` in `sw.js`.

Files involved: `index.html`, `manifest.webmanifest`, `sw.js`, `icon-192.png`,
`icon-512.png`, `icon-maskable-512.png`.

## 3. Chrome / Edge extension

Everything is already in `extension/` (MV3). Load it unpacked:

1. `chrome://extensions` → enable **Developer mode**
2. **Load unpacked** → select the `extension/` folder
3. Click the powertoy toolbar icon → opens the app in a full tab

To publish: zip the `extension/` folder and upload to the Chrome Web Store. No permissions
are requested; the app page is bundled, so it runs offline.

Keep it in sync after editing the app: `cp index.html manifest.webmanifest icon-*.png extension/`.

## 4. Native macOS app (built, no dependencies)

A genuine `.app` using AppKit + WKWebView — no Electron, no Rust, no npm. ~600 KB.

```bash
native/build-macos.sh
open native/build/powertoy.app          # first launch: right-click → Open (unsigned)
```

Requires only the Xcode command-line tools (`swiftc`, already present if you have Xcode CLT).
The build compiles `Sources/main.swift`, bundles `index.html` + icons into
`Contents/Resources`, generates a `.icns`, writes `Info.plist`, and ad-hoc signs it.

To distribute it to others without the Gatekeeper warning, sign + notarize with an Apple
Developer ID:

```bash
codesign --deep --force --options runtime --sign "Developer ID Application: …" native/build/powertoy.app
xcrun notarytool submit … && xcrun stapler staple native/build/powertoy.app
```

## Cross-platform native (Windows / Linux) — options

The macOS app above is macOS-only. For a single codebase that builds native binaries on
all three OSes, wrap the same `index.html` with one of:

- **Tauri** (recommended, tiny — uses the OS webview, ~3–10 MB):
  ```bash
  npm create tauri-app@latest        # choose "vanilla", point frontendDist at this folder
  # set tauri.conf.json → build.frontendDist = "../"  and  app.windows[0].title = "powertoy"
  npm run tauri build
  ```
- **Electron** (heavier ~100 MB, zero webview surprises):
  ```bash
  npm i -D electron
  # main.js: app.whenReady().then(()=>{const w=new BrowserWindow({width:1200,height:820}); w.loadFile('index.html')})
  npx electron .
  npx electron-builder           # to produce installers
  ```

Both load the unmodified `index.html`, so the app stays the single source of truth.

---

## Updating — how each channel gets your changes

The PWA serves `index.html` live, so it auto-updates. The extension and native app each
bundle a **snapshot** of `index.html`, so they update only when you re-sync/rebuild.

| Channel | Auto-update? | What happens on a change to `index.html` |
|---------|-------------|------------------------------------------|
| **PWA** | ✅ automatic | The service worker is *network-first* for the page: every online load fetches the latest `index.html` (bypassing the HTTP cache) and re-caches it. Users get the new version on their next open/reload while online; offline they keep the last cached copy. No version bumping needed. |
| **Chrome extension** | ⚠️ via the Store | CI builds `powertoy-extension.zip` on each tag (version from the tag). **Unpacked (dev):** `./sync.sh` then reload at `chrome://extensions`. **Published:** upload the release zip — Chrome auto-updates installed users within a few hours. |
| **Native macOS app** | ❌ manual / CI | On a tag, CI builds and publishes it. Locally, `./sync.sh` (or `native/build-macos.sh`) rebuilds it. For an auto-updating installed app, add [Sparkle](https://sparkle-project.org) or ship via the Mac App Store. |

**One command to propagate an app change into the local extension + native build:**

```bash
./sync.sh      # copies index.html into extension/ and rebuilds the native app (for local testing)
```

Only the PWA needs nothing — it's always live.

If you change `sw.js` itself (not just the app), bump `CACHE` in it so browsers detect the
new worker and reinstall.

## Testing

- `tests.html` — open in a browser (or serve + visit). Drives every tool in a live iframe
  with known-answer vectors and prints a pass/fail report. 111 assertions across 94 tools.
- `verify-commands.sh` — runs each tool's documented shell command on your machine and
  checks it matches the tool's output. Needs GNU coreutils, openssl, jq, python3.

```bash
python3 -m http.server 8000 & open http://localhost:8000/tests.html
./verify-commands.sh
```
