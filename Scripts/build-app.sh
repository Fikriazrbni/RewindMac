#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-release}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
mkdir -p .build dist
swift build -c "$configuration" --disable-sandbox
binary_dir="$(swift build -c "$configuration" --show-bin-path --disable-sandbox)"
app="$PWD/dist/RewindMac.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/RewindMac" "$app/Contents/MacOS/RewindMac"
cp Resources/Info.plist "$app/Contents/Info.plist"
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" Scripts/make-icon.swift Sources/RewindMac/RewindMark.swift -o .build/make-icon
.build/make-icon "$PWD/.build/AppIcon.iconset"
iconutil -c icns .build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$app"
print "Built: $app"
