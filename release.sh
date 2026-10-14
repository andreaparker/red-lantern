#!/bin/zsh
# Build an ad-hoc-signed universal app; no Developer ID or notarization is implied.
set -euo pipefail
cd "${0:A:h}"

OUTPUT='build/release'
APP="$OUTPUT/Red Lantern.app"
ARCHIVE='Red-Lantern-macOS-universal.zip'
rm -rf "$OUTPUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/module-cache

build_architecture() {
  local architecture="$1"
  xcrun clang -Os -arch "$architecture" -mmacosx-version-min=14.0 \
    "-ffile-prefix-map=$PWD=/src/red-lantern" "-ffile-prefix-map=$HOME=/home/build" \
    Tools/Guardian.c -framework CoreGraphics -o "$OUTPUT/guardian-$architecture"
  xcrun swiftc -O -swift-version 5 -target "$architecture-apple-macos14.0" \
    -file-prefix-map "$PWD=/src/red-lantern" -file-prefix-map "$HOME=/home/build" \
    -file-compilation-dir /src/red-lantern -module-cache-path build/module-cache \
    Sources/*.swift -o "$OUTPUT/app-$architecture"
}

assemble_executable() {
  local prefix="$1" executable="$2"
  xcrun lipo -create "$OUTPUT/$prefix-arm64" "$OUTPUT/$prefix-x86_64" \
    -output "$APP/Contents/MacOS/$executable"
  xcrun strip -x "$APP/Contents/MacOS/$executable"
  xcrun lipo "$APP/Contents/MacOS/$executable" -verify_arch arm64 x86_64
}

build_architecture arm64
build_architecture x86_64
assemble_executable app RedLantern
assemble_executable guardian LanternGuardian
cp Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
xcrun swift -module-cache-path build/module-cache Tools/Icon.swift "$APP/Contents/Resources"
codesign --force --sign - --timestamp=none "$APP/Contents/MacOS/LanternGuardian"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --keepParent --norsrc --noextattr --noacl "$APP" "$OUTPUT/$ARCHIVE"
python3 Tests/release_package.py "$OUTPUT/$ARCHIVE"

mkdir "$OUTPUT/verify"
ditto -x -k "$OUTPUT/$ARCHIVE" "$OUTPUT/verify"
codesign --verify --deep --strict "$OUTPUT/verify/Red Lantern.app"
for executable in RedLantern LanternGuardian; do
  xcrun lipo "$OUTPUT/verify/Red Lantern.app/Contents/MacOS/$executable" \
    -verify_arch arm64 x86_64
done
(cd "$OUTPUT" && shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt && shasum -a 256 -c SHA256SUMS.txt)
echo "Release archive: $PWD/$OUTPUT/$ARCHIVE"
