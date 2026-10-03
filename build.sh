#!/bin/bash
# Builds a release binary and wraps it in build/Mac-a-notch.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/Mac-a-notch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/MacANotch "$APP/Contents/MacOS/MacANotch"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Mac-a-notch</string>
  <key>CFBundleIdentifier</key><string>com.rithvik.macanotch</string>
  <key>CFBundleExecutable</key><string>MacANotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Mac-a-notch shows your upcoming events and meeting links in the notch.</string>
  <key>NSCalendarsUsageDescription</key><string>Mac-a-notch shows your upcoming events and meeting links in the notch.</string>
  <key>NSCameraUsageDescription</key><string>Mac-a-notch can show a quick camera mirror in the notch.</string>
  <key>NSBluetoothAlwaysUsageDescription</key><string>Mac-a-notch shows a HUD when AirPods and other Bluetooth audio devices connect.</string>
  <key>NSAppleEventsUsageDescription</key><string>Mac-a-notch reads the current track from Music and Spotify and controls playback.</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP — run: open $APP"
