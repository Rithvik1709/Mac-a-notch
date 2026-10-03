# Mac-a-notch

A Droppy-style utility that turns the MacBook notch (or a Dynamic Island pill on Macs without one) into a hub.

## Features
- **Notch shelf** – hover the notch (or drag a file toward it) to expand; drop files to park them, drag them back out, double-click to open, right-click for Reveal / Copy / AirDrop.
- **Floating basket** – jiggle the cursor while dragging a file to summon a drop zone anywhere on screen; items land on the shelf.
- **Clipboard manager** – history with search, favorites, image capture, OCR (Vision) on image clips; skips password managers and concealed copies.
- **Media player** – Apple Music and Spotify: artwork (Spotify), title, artist, play/pause/next/previous.
- **Settings** – toggle each feature, hover-to-open, haptics, history size, Dynamic Island mode, launch at login.

Not yet implemented (present in Droppy): custom volume/brightness HUDs, AirPods HUD, quick share/cloud upload, voice transcription, background removal, window snapping.

## Build & run
Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools).

    ./build.sh
    open build/Mac-a-notch.app

The first time you use the media tab, macOS asks for permission to control Music/Spotify.
