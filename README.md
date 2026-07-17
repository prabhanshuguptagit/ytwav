# YtWav

Tiny macOS menu bar app: paste a YouTube URL, get a WAV in `~/Downloads`, with the file also copied to your clipboard (paste it straight into Finder or a DAW).

## Install yt-dlp

The app looks for `yt-dlp_macos` in `~/.local/bin` (recommended), `/usr/local/bin`, `/opt/homebrew/bin`, `~/bin`, or `~/Downloads` (and falls back to plain `yt-dlp`).

Recommended: `~/.local/bin` — user-owned, so installing and self-updating (`yt-dlp_macos -U`) need no sudo:

```sh
mkdir -p ~/.local/bin
mv /path/to/yt-dlp_macos ~/.local/bin/
chmod +x ~/.local/bin/yt-dlp_macos
xattr -d com.apple.quarantine ~/.local/bin/yt-dlp_macos 2>/dev/null || true
```

The `xattr` line removes the "downloaded from the internet" quarantine flag so macOS doesn't block it.

To also use it from Terminal in any folder, add to `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Alternatively, via Homebrew (no sudo, auto-updates):

```sh
brew install yt-dlp
```

### ffmpeg (required)

yt-dlp needs ffmpeg to convert audio to WAV:

```sh
brew install ffmpeg
```

## Install from a release

Download `YtWav-vX.zip` from Releases, unzip, then strip the quarantine flag (the app is ad-hoc signed, not notarized, so macOS blocks it otherwise):

```sh
xattr -cr YtWav.app
open YtWav.app
```

Releases are built automatically by GitHub Actions when a `v*` tag is pushed:

```sh
git tag v1.0 && git push origin v1.0
```

## Build & run

```sh
./build.sh
open YtWav.app
```

Click the ↓ icon in the menu bar, paste a URL, hit **Download WAV**. Live yt-dlp logs show in the panel.

To keep it running after reboots: drag `YtWav.app` into System Settings → General → Login Items.

## Updating yt-dlp

YouTube changes things often; if downloads start failing, update:

```sh
yt-dlp_macos -U        # standalone binary
brew upgrade yt-dlp    # homebrew
```
