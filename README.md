# Mac-a-notch

A utility that turns the MacBook notch into a hub — or a Dynamic Island–style pill on Macs without one.
Inspired by apps like Droppy, NotchNook and Boring Notch. It is an independent project and is not affiliated with any of them.

Requires **macOS 14 (Sonoma) or later**. Runs on Apple Silicon and Intel.

## Install

### Option 1 — Download the app (easiest)

1. Download `Mac-a-notch-<version>.zip` from the [Releases](../../releases) page and unzip it.
2. Drag **Mac-a-notch.app** into your **Applications** folder (needed for *Launch at login* to work).
3. The app is not notarized by Apple, so macOS blocks the first launch. Either:
   - **Right-click** the app → **Open** → **Open**, or
   - run `xattr -cr /Applications/Mac-a-notch.app` in Terminal, then open it normally.
4. Look for the icon in the menu bar. There is no Dock icon and no window — hover the notch to open it.

### Option 2 — Build from source

Needs the Swift toolchain (Xcode or the Command Line Tools: `xcode-select --install`).

```sh
git clone <this repo>
cd Mac-a-notch
./build.sh                 # builds for this Mac
open build/Mac-a-notch.app
```

To make a universal (Apple Silicon + Intel) zip for sharing:

```sh
./package.sh               # -> build/Mac-a-notch-<version>.zip
```

## Features

Hover the notch (or drag a file toward it) to open it. Each tab can be switched off in **Settings**.

| Tab / feature | What it does |
|---|---|
| **Shelf** | Drop files to park them, drag them back out, AirDrop, Reveal, Copy. Zip files, convert images (HEIC/PNG/JPEG). |
| **Floating basket** | Jiggle the cursor while dragging a file to get a drop zone anywhere on screen. |
| **Clipboard** | History with search, favorites, images and OCR. Skips password managers and concealed copies. |
| **Media** | Apple Music, Spotify and browser tabs (YouTube, YouTube Music, SoundCloud, Spotify Web). Seek bar, shuffle, repeat. |
| **Live activity** | While something plays, the collapsed notch shows artwork and a scrolling title. |
| **Calendar** | Upcoming events, one-click **Join** for Zoom/Meet/Teams/Webex links, a heads-up 5 minutes before. |
| **Timer** | Pomodoro with a countdown in the collapsed notch. |
| **Claude** | Shows Claude Code sessions (working / needs input / finished) — see setup below. |
| **Shortcuts** | Run your Apple Shortcuts. |
| **System** | CPU, GPU, memory, disk and network. |
| **Mirror** | Quick camera preview (camera is only on while the tab is open). |
| **Tools** | High Alert (keep the Mac awake) and an emoji picker. |
| **HUDs** | Volume, brightness, AirPods connect, battery (plug/unplug, low, full), Caps Lock, lock/unlock. |

## Permissions

macOS asks only when you first use a feature. Nothing is required to launch.

| Permission | Used for |
|---|---|
| Calendars | Calendar tab and meeting alerts |
| Camera | Mirror tab |
| Bluetooth | AirPods / Bluetooth audio HUD |
| Automation (Music, Spotify, your browser) | Reading and controlling playback |

**Browser media:** for song details, artwork, correct pause detection and play/pause from the notch,
enable *View → Developer → Allow JavaScript from Apple Events* in Chrome, Brave, Arc, Edge, Comet etc.
(Safari: *Develop → Developer Settings → Allow JavaScript from Apple Events*).
Without it the app falls back to the tab title and macOS's audio activity, which reacts a few seconds late on pause.

## Claude Code status setup

1. Open the **Claude** tab and click **Copy hook config**.
2. Merge the copied `hooks` block into `~/.claude/settings.json`.
3. Start a Claude Code session. The app installs `~/.macanotch/claude-hook.sh` on launch.

## Known limitations

- **Lock screen widgets are not supported.** macOS gives apps no supported way to draw there.
- System-wide Now Playing is not used; macOS 15.4+ restricts it. Media comes from Music, Spotify and browser tabs.
- The brightness HUD reads brightness through a private Apple framework (`DisplayServices`), which could break in a future macOS release.
- macOS's own volume/brightness overlay still appears alongside ours.
- Not notarized, so Gatekeeper needs the one-time override above.
