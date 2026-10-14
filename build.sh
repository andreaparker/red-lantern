#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/module-cache 'build/Red Lantern.app/Contents/MacOS' 'build/Red Lantern.app/Contents/Resources'
APP='build/Red Lantern.app'
xcrun clang -Os -mmacosx-version-min=14.0 Tools/Guardian.c -framework CoreGraphics \
  -o "$APP/Contents/MacOS/LanternGuardian"
xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14.0" \
  -module-cache-path build/module-cache Sources/*.swift -o "$APP/Contents/MacOS/RedLantern"
cp Info.plist "$APP/Contents/Info.plist"
xcrun swift -module-cache-path build/module-cache Tools/Icon.swift "$APP/Contents/Resources"
codesign --force --sign - "$APP/Contents/MacOS/LanternGuardian"
codesign --force --sign - "$APP"
echo "Built: $PWD/$APP"
