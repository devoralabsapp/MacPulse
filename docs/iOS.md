# MacPulse for iPhone and iPad

[Tiếng Việt](iOS.vi.md) · [Project overview](../README.md)

The native SwiftUI app targets **iOS/iPadOS 17 or later**. It uses a tab bar on compact screens and a sidebar when there is room on iPad, including multitasking. It shares themes, translations, formatting, and rate calculations with the Mac app. It measures the device on which it runs; it does not remotely monitor a Mac.

## Run on your iPhone or iPad

1. Open `iOS/MacPulse.xcodeproj` in Xcode (Swift 6 toolchain or later).
2. Select the **MacPulse-iOS** scheme and the **MacPulseMobile** target.
3. Under **Signing & Capabilities**, select your development Team. Change `com.macpulse.mobile` to a bundle identifier your Team can register if needed. No Team or signing credentials are committed.
4. Connect your iPhone/iPad, enable Developer Mode when prompted, select it as the run destination, and press **Run (⌘R)**.

You can also select an installed iPhone/iPad Simulator and Run without a paid developer account. A personal Team can run development builds subject to Apple's current signing limits. TestFlight/App Store distribution requires your own account, signing, and submission; this repository does not publish an iOS release for you. See [Apple's device setup](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device).

## What the iOS app measures

| Feature | Scope |
| --- | --- |
| CPU | MacPulse process CPU time, normalized across the reported core count; **not system-wide CPU** |
| RAM | MacPulse physical memory footprint, reported device physical RAM, and advisory app allocation headroom; **not total RAM used by other apps** |
| Storage | Capacity and available bytes of the app's volume; may differ from Settings because of APFS/purgeable storage |
| Battery | Percentage, charging state, Low Power Mode, and OS thermal state. mAh, design capacity, health, and cycles are not inferred |
| Network | Observed physical-interface upload/download rates, chart, per-interface status, and session totals while active |
| Files | Large/old files inside a directory explicitly selected through Files; preview, manual selection, Recovery, restore, and confirmed permanent deletion |
| Appearance | Ocean / Forest / Violet / Graphite; System default / Light / Dark; English / Vietnamese |

Sampling pauses when the app is inactive. Resume starts new CPU/network baselines. Public iOS interface byte counters can wrap; a decrease/reset creates a gap rather than a guessed delta. Traffic can include other apps and the local network, and does not measure your plan speed or billable cellular usage. Network path status is not a reachability test. No speed-test requests, packet capture, IP/SSID collection, analytics, or account login are implemented.

Simulator hardware readings may reflect the host Mac. Battery data can be unavailable, shown as **—**. Simulator success does not establish physical-device battery accuracy or App Store approval.

Apple's public [battery API](https://developer.apple.com/documentation/uikit/uidevice/batterylevel) provides battery level; [app memory headroom](https://developer.apple.com/documentation/os/os_proc_available_memory) is advisory and distinct from free system RAM. The app uses only its own process task information and does not inspect another app's private data.

## File cleanup and recovery

Choose a folder in Files, then review files ≥100 MB or unmodified for ≥180 days. No file is selected automatically. iOS cannot perform the Mac version's open-file/process inspection; mobile candidates are **review first** or blocked, never certified unused. Known sensitive/database/backup/incomplete formats, symlinks, packages, locked files, and multiple links are excluded or blocked.

**Move to Recovery** relocates selected files into a visible `MacPulse Recovery` folder **inside the chosen directory/provider**. This is not the system Trash or the Files app's Recently Deleted area. It still consumes storage. Reopening that same folder lets MacPulse read its recovery records after a restart. The app retains a minimal security-scoped bookmark; if permission expires, choose the folder again.

- **Restore** moves a validated payload back to its original location, never overwriting an existing file. If its parent folder has been removed or replaced, restore it manually using Files.
- **Delete Permanently** requires a separate review and removes the validated recovery entry. MacPulse cannot undo it. Actual physical space reclaimed depends on APFS and the provider's retention behavior.
- Provider-backed folders may sync moves/deletions to iCloud or other devices. The app displays this before confirmation. Metadata-only scans skip undownloaded iCloud files; previewing a file may let its provider fetch its content.
- A folder with the recovery name but without MacPulse's format marker is never adopted or overwritten. If records are damaged or files changed in Files, the app declines unsafe operations; payloads remain visible in the recovery folder for manual retrieval.

File access uses the document picker's grant, balanced security-scope lifetimes, file coordination, and fresh metadata/path checks. These reduce stale-selection risk but do not prove a file is unused or provide an atomic defense against all provider changes. Test your provider with disposable files first. See [Apple's directory access guide](https://developer.apple.com/documentation/uikit/providing-access-to-directories).

## Build and test

```sh
bash scripts/test.sh                    # shared + Mac regression tests on macOS
bash scripts/build-ios.sh               # unsigned Simulator app + ZIP in dist/
bash scripts/build-ios.sh --device      # unsigned arm64 device build, not installable as-is
bash scripts/test-ios.sh                # core/device/UI tests on an available iPhone Simulator
```

Choose a particular phone/tablet with `DESTINATION='platform=iOS Simulator,id=YOUR-SIMULATOR-UUID' bash scripts/test-ios.sh`. Find identifiers with `xcrun simctl list devices available`. XCTest uses disposable file fixtures and never selects or cleans a user's real folder.

The Xcode project is committed. Regeneration is optional: install the Ruby `xcodeproj` gem and run `ruby scripts/generate-ios-project.rb`. No third-party runtime libraries are used. Regenerate the opaque app icon with `swift scripts/generate-ios-icon.swift iOS/MacPulse/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

`PrivacyInfo.xcprivacy` declares local preferences, elapsed-time measurement, user-visible disk capacity, and metadata access in app/user-selected directories. Review the [Apple-required reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons) when changing API usage or preparing distribution.
