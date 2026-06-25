# powertoy — developer utilities

A single-file webapp with 88 everyday utilities for developers and power users.
Every tool shows its **shell equivalent** (bash / unix command) alongside the result.
Works offline from a plain `file://` open — no build, no install, no server.

## Run it

```bash
open index.html        # macOS — just open the file
xdg-open index.html    # Linux
```

Or host it on **GitHub Pages**, or run it as an **installable PWA**, a **Chrome extension**,
or a **native macOS app** — all fully offline. The hosted page links to the latest macOS
app release and shows the current version. See [PACKAGING.md](PACKAGING.md).

## Quality

- **`tests.html`** — integration suite: drives every tool in a live iframe with
  known-answer vectors (104 assertions across all 88 tools). Open it to see a pass/fail report.
- **`verify-commands.sh`** — runs each tool's documented shell command on your machine and
  confirms it matches the tool's output (43 checks).

## Tools

| Group   | Tool              | Anchor    |
|---------|-------------------|-----------|
| Encode  | Base64            | `#base64` |
| Encode  | URL encode        | `#url`    |
| Encode  | HTML entities     | `#entity` |
| Encode  | JWT decode        | `#jwt`    |
| Encode  | Hex encode        | `#hex`    |
| Encode  | Base32            | `#b32`    |
| Encode  | Unicode escape    | `#uni`    |
| Encode  | ROT13 / Caesar    | `#rot`    |
| Encode  | URL parser        | `#urlparse` |
| Encode  | Gzip / Deflate    | `#gz`     |
| Encode  | Data URI          | `#duri`   |
| Encode  | Base58            | `#b58`    |
| Encode  | Binary text       | `#bin`    |
| Encode  | JSON escape       | `#jstr`   |
| Encode  | Punycode / IDN    | `#puny`   |
| Encode  | Morse code        | `#morse`  |
| Encode  | Shell quote       | `#shquote` |
| Encode  | QR code           | `#qr`     |
| Encode  | Base85            | `#b85`    |
| Encode  | Base62            | `#b62`    |
| Convert | Color convert     | `#color`  |
| Convert | Color fade        | `#fade`   |
| Convert | Number base       | `#radix`  |
| Convert | Contrast check    | `#contrast` |
| Convert | Palette maker     | `#palette` |
| Convert | Image palette     | `#imgpal` |
| Convert | Bitwise calc      | `#bitw`   |
| Convert | Image resize      | `#img`    |
| Convert | IEEE 754 float    | `#ieee`   |
| Convert | Easing curve      | `#bezier` |
| Convert | CSS gradient      | `#gradient` |
| Convert | Box shadow        | `#shadow` |
| Convert | Aspect ratio      | `#aspect` |
| Convert | Favicon generator | `#favicon` |
| Time    | Epoch time        | `#time`   |
| Time    | Timezone convert  | `#tz`     |
| Time    | Cron expression   | `#cron`   |
| Time    | Date math         | `#dmath`  |
| Time    | Duration convert  | `#dur`    |
| Units   | Weight convert    | `#wt`     |
| Units   | Length convert    | `#len`    |
| Units   | Volume convert    | `#vol`    |
| Units   | Area convert      | `#area`   |
| Units   | Speed convert     | `#spd`    |
| Units   | Fuel economy      | `#fuel`   |
| Units   | Temperature       | `#temp`   |
| Units   | Data size         | `#data`   |
| Units   | Angle convert     | `#angle`  |
| Crypto  | Hash digest       | `#hash`   |
| Crypto  | Encrypt / decrypt | `#aes`    |
| Crypto  | Password gen      | `#pw`     |
| Crypto  | Random string     | `#random` |
| Crypto  | UUID & ID gen     | `#uuid`   |
| Crypto  | TOTP code         | `#totp`   |
| Ops     | CIDR subnet       | `#cidr`   |
| Ops     | Chmod calculator  | `#chmod`  |
| Ops     | curl convert      | `#curl`   |
| Ops     | Connection / WiFi | `#wifi`   |
| Ops     | Device info       | `#device` |
| Crypto  | XOR cipher        | `#xor`    |
| Crypto  | HMAC              | `#hmac`   |
| Crypto  | JWT signer        | `#jwtsign` |
| Crypto  | ID decoder        | `#iddecode` |
| Crypto  | Certificate decoder | `#x509` |
| Crypto  | File checksum     | `#filehash` |
| Text    | JSON format       | `#json`   |
| Text    | Regex tester      | `#rgx`    |
| Text    | Case convert      | `#case`   |
| Text    | Text stats        | `#stats`  |
| Text    | Text diff         | `#diff`   |
| Text    | CSV ↔ JSON        | `#csv`    |
| Text    | Query ↔ JSON      | `#qs`     |
| Text    | Line tools        | `#lines`  |
| Text    | Regex replace     | `#rrep`   |
| Text    | Lorem ipsum       | `#lorem`  |
| Text    | JSON → types      | `#j2t`    |
| Text    | JSON query        | `#jsonquery` |
| Text    | Markdown preview  | `#md`     |
| Text    | Mock data         | `#mock`   |
| Text    | Whitespace inspect| `#ws`     |
| Text    | Slugify           | `#slug`   |
| Text    | ASCII art         | `#asciiart` |
| Reference | HTTP status     | `#http`   |
| Reference | ASCII table     | `#ascii`  |
| Reference | Common ports    | `#ports`  |
| Reference | Keycode finder  | `#keycode` |
| Reference | Emoji search    | `#emoji`  |
| Reference | MIME types      | `#mime`   |

## Notes

- JWT decoding accepts tokens with a leading `Bearer ` / `Authorization:` prefix.
- Encryption is AES-256-GCM with PBKDF2-SHA256 (200k iterations); the output blob is
  `base64(salt[16] ∥ iv[12] ∥ ciphertext+tag)` — decrypt with the same tool.
- Cron supports 5-field expressions plus `@daily`-style aliases, with next-run preview.
- Timezone list comes from the browser's own IANA database (`Intl.supportedValuesOf`).
- Press `/` to search tools, or `⌘K`/`Ctrl-K` for the command palette; tools are deep-linkable via URL hash (e.g. `index.html#cron`).
- Smart paste: paste a JWT, epoch, JSON, curl command, CIDR, color, etc. anywhere (outside a field) and the app offers to open the right tool prefilled.
- Pin tools with the ☆ star — they float to the top of the sidebar.
- Tool chaining: every result has a **Send to →** button that pipes its output into another tool's input (e.g. Base64 decode → JSON format → JSON query).
- Dark mode: toggle in the header (follows your OS preference by default).
- The last-used tool and your inputs are remembered locally between sessions.
