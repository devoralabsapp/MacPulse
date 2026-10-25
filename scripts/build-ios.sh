#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
kind=Simulator
sdk=iphonesimulator
destination='generic/platform=iOS Simulator'
if [[ "${1:-}" == "--device" ]]; then
    kind=Device-unsigned
    sdk=iphoneos
    destination='generic/platform=iOS'
elif [[ -n "${1:-}" ]]; then
    printf 'Usage: bash scripts/build-ios.sh [--device]\n' >&2
    exit 2
fi
xcodebuild -project iOS/MacPulse.xcodeproj -scheme MacPulse-iOS -configuration Release \
    -sdk "$sdk" -destination "$destination" -derivedDataPath ".build/ios-release-$sdk" \
    CODE_SIGNING_ALLOWED=NO build
output="$PWD/dist/iOS-$kind/MacPulse.app"
mkdir -p "$(dirname "$output")"
rm -rf "$output"
ditto ".build/ios-release-$sdk/Build/Products/Release-$sdk/MacPulse.app" "$output"
plutil -lint "$output/Info.plist" "$output/PrivacyInfo.xcprivacy"
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift scripts/verify-ios-app.swift "$output"
if [[ "$sdk" == "iphoneos" ]]; then lipo "$output/MacPulse" -verify_arch arm64; fi
ditto -c -k --sequesterRsrc --keepParent "$output" "$PWD/dist/MacPulse-iOS-$kind.zip"
printf '\nCreated: %s\n' "$output"
if [[ "$kind" == 'Device-unsigned' ]]; then
    printf 'Unsigned device build: use Xcode Signing & Capabilities to sign and install on your device.\n'
fi
