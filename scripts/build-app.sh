#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

architecture=()
if [[ "${1:-}" == "--universal" ]]; then
    architecture=(--arch arm64 --arch x86_64)
fi
options=(--disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security)
swift build -c release "${options[@]}" ${architecture[@]+"${architecture[@]}"}
binary_dir=$(swift build -c release "${options[@]}" ${architecture[@]+"${architecture[@]}"} --show-bin-path)
app="$PWD/dist/MacPulse.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/MacPulse" "$app/Contents/MacOS/MacPulse"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE"
# SwiftPM's single-architecture and Universal builds use different bundle layouts.
# Replace this generated bundle so old Contents/ resources cannot shadow a later build.
rm -rf "$app/Contents/Resources/MacPulse_MacPulseCore.bundle"
for resource_bundle in "$binary_dir"/*.bundle; do
    [[ -d "$resource_bundle" ]] || continue
    ditto "$resource_bundle" "$app/Contents/Resources/$(basename "$resource_bundle")"
done
for localized_metadata in Resources/*.lproj; do
    [[ -d "$localized_metadata" ]] || continue
    ditto "$localized_metadata" "$app/Contents/Resources/$(basename "$localized_metadata")"
done
swift scripts/generate-icon.swift "$PWD/.build/AppIcon.iconset"
cp .build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$app"
swift scripts/verify-app.swift "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$PWD/dist/MacPulse.zip"
printf '\nĐã tạo: %s\n' "$app"
printf 'Mở app: open "%s"\n' "$app"
