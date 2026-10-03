#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Mac-a-notch.app and zips it for sharing.
# Output: build/Mac-a-notch-<version>.zip  (+ SHA-256 printed for release notes)
set -euo pipefail
cd "$(dirname "$0")"

TARGET=14.0
for arch in arm64 x86_64; do
  echo "==> Building $arch"
  swift build -c release --triple "$arch-apple-macosx$TARGET"
done

mkdir -p build
lipo -create \
  ".build/arm64-apple-macosx/release/MacANotch" \
  ".build/x86_64-apple-macosx/release/MacANotch" \
  -output build/MacANotch-universal
lipo -info build/MacANotch-universal

BIN=build/MacANotch-universal ./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Mac-a-notch.app/Contents/Info.plist)
ZIP="build/Mac-a-notch-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/Mac-a-notch.app "$ZIP"
echo
echo "Created $ZIP"
shasum -a 256 "$ZIP"
