# MacPulse

**Know what your Mac is doing. Choose what to clean up.**

[![Apple platforms CI](https://github.com/devoralabsapp/MacPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/devoralabsapp/MacPulse/actions/workflows/ci.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-202b3c)
![Swift 6+](https://img.shields.io/badge/Swift-6%2B-orange)

[Tiếng Việt](README.vi.md) · [Contributing](CONTRIBUTING.md) · [Roadmap](ROADMAP.md) · [Report a bug](https://github.com/devoralabsapp/MacPulse/issues/new/choose)

MacPulse is a native macOS utility for monitoring CPU, memory, storage, battery, and network activity, with a file cleanup workflow that lets you review each candidate before moving it to Trash. Built with SwiftUI, AppKit, and IOKit, it runs locally without accounts, analytics, or third-party dependencies. The app supports English and Vietnamese, selectable in Settings.

**Early development:** core tests, Universal builds, and offscreen view renders have been checked locally. Interactive controls and the full Trash workflow still need manual verification. Builds are ad hoc signed and are not notarized by Apple. See [verification notes](VERIFICATION.md) for the exact scope of validation.

## Why MacPulse?

System information should be understandable, and file cleanup should be a decision you control. MacPulse brings resource monitoring and file discovery into one app, makes battery charge available in **mAh when the hardware provides it**, and explains the limits of each measurement.

It does not treat an old modification date as proof that a file is unused. It shows candidates, their locations, sizes, and dates so you can decide what to keep.

## iPhone and iPad

A native **iOS/iPadOS 17+** app is included in `iOS/MacPulse.xcodeproj`, scheme **MacPulse-iOS**. It adapts to iPhone tabs and an iPad sidebar, with the same themes and languages. It monitors its own process CPU/RAM, storage, battery percentage, and network counters, and reviews files in a folder you grant through Files. iOS does not offer the Mac app's full hardware/private-file access; mAh and other apps' CPU/RAM are not fabricated.

[Build, device signing, platform limits, and recovery guide](docs/iOS.md) · [Hướng dẫn tiếng Việt](docs/iOS.vi.md)

## Features (macOS)

| Area | What you can inspect |
| --- | --- |
| CPU | Total utilization, user/system/idle breakdown, core count, and a 60-sample history |
| Memory | Used, wired, compressed, cached memory, swap, and memory pressure when available |
| Storage | Capacity, used space, and available space on the volume containing your home folder |
| Battery | Charge percentage, remaining mAh, distinct full-charge and firmware design capacities, cycle count, a health estimate only for consistent references, macOS-reported condition, voltage, current, and time estimates when available |
| Network | Dedicated live upload/download view, 60-sample chart, per-interface rates/status, observed session totals, byte/bit units, and optional menu bar speeds |
| File cleanup | Large files ≥100 MB, files unmodified for ≥180 days, and optional user cache/log files ≥30 days old |
| Menu bar | A live CPU readout and a compact resource summary |
| Appearance | Ocean, Forest, Violet, and Graphite palettes; System default, Light, and Dark modes; saved preferences |

Cleanup results support search, category/risk filters, per-file reasons, multiple selection, and **Reveal in Finder**. Nothing is selected automatically. A confirmation sheet lists the selected files and their assessment before any Trash operation.

## Get started

Requirements: **macOS 14 or later** and **Swift 6 or later** through Xcode or Command Line Tools. Only Apple system frameworks are used.

```sh
git clone https://github.com/devoralabsapp/MacPulse.git
cd MacPulse
bash scripts/test.sh
bash scripts/build-app.sh
open dist/MacPulse.app
```

Build a Universal app for both Apple Silicon and Intel:

```sh
bash scripts/build-app.sh --universal
```

The build script generates `dist/MacPulse.app` and `dist/MacPulse.zip`, including an app icon, Info.plist, and an ad hoc signature. You can drag the app into Applications for local use. Public distribution with a Developer ID signature and Apple notarization is future work.

Open `Package.swift` in Xcode to work on the source. Use the packaged `.app` when testing folder permissions. Closing the main window keeps menu bar monitoring available; choose **Thoát MacPulse** in the menu bar panel to quit.

## Appearance

Use the **palette icon** at the top right of the main window to choose **Ocean, Forest, Violet, or Graphite** and **System default, Light, or Dark**. Open **Settings (⌘,) → Appearance** for visual palette previews. System default follows macOS appearance, including its automatic changes.

The choice is saved and shared by app windows, Settings, the menu bar popup, and app-owned sheets. Switching themes preserves monitoring history, scan results, and file selection. Safety labels retain their own green/amber/red meanings across palettes. The macOS status item and system-owned dialogs use native system styling.

## Language

Open the sidebar gear or press **⌘,**, then choose **General / Cài đặt chung → Language / Ngôn ngữ → English, Tiếng Việt, or System default**. The choice is saved and updates app screens, the custom menu bar panel, and app messages immediately. Existing scan results can change language without rescanning or losing selection. macOS-owned dialogs and standard system menus follow macOS language preferences.

## Monitor upload and download

Open **Network / Mạng** in the sidebar, or use the arrow on the Overview network card. The page shows current upload/download speed, a chart of the last 60 samples, the peak within that chart, observed session traffic, and each physical interface's rates and active/inactive state. Interface activity does not establish Internet reachability.

Choose **KB/s · MB/s** or **Kbps · Mbps** on the page or in **Settings → General**. Network units are decimal: **1 MB/s = 8 Mbps**. The same choice applies to Overview and the menu bar panel. Menu bar speeds are enabled by default and can be hidden in Settings without stopping collection.

Rates use 64-bit kernel interface counters and actual monotonic elapsed time, not a fixed assumed timer interval. The first sample, new/reconnected interfaces, reset counters, and gaps establish a baseline rather than creating false speed spikes. Missing samples remain gaps in the chart. Valid idle samples show zero; unavailable samples show `—`.

Statistics include LAN and background traffic on supported physical interfaces (`en*` and `pdp_ip*`). Loopback, VPN, and bridge interfaces are excluded from the sum. This is traffic monitoring, not a speed test, per-app attribution, packet-content capture, or a measurement of your Internet plan's maximum speed. Session totals include only valid observed intervals and reset when the app exits; they are not billing records or lifetime totals.

## Clean up files deliberately

1. Open **Dọn dẹp** (Cleanup), choose a folder, or use Downloads.
2. Optionally include old user caches and logs, then start the scan.
3. Inspect the results and reveal unfamiliar files in Finder.
4. Use the risk filter or **Select only lower-risk files**, then choose **Chuyển vào Thùng rác** (Move to Trash) and review the confirmation list. The lower-risk action replaces your current selection with the visible lower-risk items.
5. Restore files using Finder's **Put Back** if needed. Space is reclaimed only after you empty Trash yourself.

The scanner reads metadata, not file contents. It skips hidden files, symlinks, aliases, app/package contents, `node_modules`, designated system locations, and the user's Library outside Caches/Logs. Cloud-only iCloud items are skipped; detected downloaded cloud files are blocked from cleanup. Scans are cancellable and limited to 100,000 entries; use a smaller folder for larger collections.

| Assessment | Meaning |
| --- | --- |
| Lower risk | Certain `.cache`, `.tmp`, or `.temp` files in the standard user Caches folder, or recognized old log formats in user Logs. Modification, creation, and access dates that are available must be at least 30 days old, open-file inspection must complete cleanly, and no matching running app/open file may be observed. |
| Review first | Personal files, unrecognized cache/log formats, recent activity, or incomplete inspection. Age and size do not prove a file is unneeded. |
| Avoid cleanup | Observed open files, running cache/log owners, detected cloud data, databases, security material, backups, incomplete downloads, locked/unwritable files, and files with multiple links. Selection is disabled. |

These labels are conservative heuristics, not a safety guarantee. The app checks the current user's open files using macOS `lsof`, with a timeout, and reads running app bundle IDs. Warnings, failure, empty results, or timeout disable lower-risk labels. Inspection cannot establish that no process will use a file later, and not every sync provider or valuable file can be recognized. Cache regeneration may need a network connection; deleting logs loses diagnostic history.

Before a batch moves to Trash, MacPulse refreshes open-file/running-app information and reassesses each file. Blocked files and previously lower-risk files that no longer qualify are skipped. It also rechecks the path, file identity, size, and modification time immediately before a move. These checks reduce stale-scan mistakes; they do not provide an atomic filesystem security guarantee. Start with disposable files when testing the cleanup workflow.

Folder access follows macOS privacy permissions. If access is denied, select the folder again or review **System Settings → Privacy & Security → Files and Folders**. MacPulse does not require administrator privileges, empty Trash, force-purge RAM, uninstall apps, or modify system settings.

## How the measurements work

- **CPU:** Mach `host_statistics`, calculated from the difference between samples. The first CPU reading needs one sampling interval.
- **RAM:** `host_statistics64` and `vm.swapusage`. Memory usage is calculated from active, inactive, purgeable, file-backed, wired, and compressed pages. RAM and swap use 1024-based units with macOS-style GB labels: a 32 GiB machine displays **32 GB**, while file and disk sizes retain decimal units. Values can differ from Activity Monitor because of timing and classification.
- **Disk:** Foundation volume capacity values for the home folder's volume. APFS sharing, snapshots, and purgeable space can produce differences from System Settings. Cleanup file sizes are logical sizes, not a promise of reclaimable physical space.
- **Battery:** IOPS for percentage/power state and `AppleSmartBattery` registry properties for raw charge when available, including nested `BatteryData` values. Full-charge capacity is distinct from firmware-reported `DesignCapacity`; learned `Qmax` values are not substituted for design. Raw gauge readings are not an independent physical-capacity measurement. If reported full charge exceeds the design reference, the app retains both readings, flags them for verification, and withholds its health estimate instead of displaying above 100%, inventing a new design value, or silently clamping to 100%. macOS-reported condition remains separate. Missing values display `—`; percentage is never relabeled as mAh.
- **Network:** `sysctl(NET_RT_IFLIST2)` / `if_data64` counters, per-interface deltas, and monotonic uptime. This avoids the 4 GiB wrap of the old `getifaddrs` 32-bit byte counters. SystemConfiguration supplies interface display names/types without requesting SSIDs or IP addresses. No network test requests are sent.

References: [IOPowerSources](https://developer.apple.com/documentation/iokit/iopowersources_h), [IOPMPowerSource](https://developer.apple.com/documentation/kernel/iopmpowersource), and [NSWorkspace.recycle](https://developer.apple.com/documentation/appkit/nsworkspace/recycle(_:completionhandler:)).

## Development

```text
Sources/MacPulse/          SwiftUI screens, app state, menu bar, and Trash integration
Sources/MacPulseCore/      System readers, models, scanner, and cleanup validation
Tests/MacPulseCoreTests/   Battery parsing and filesystem safety tests
Resources/                App metadata
scripts/                  Test runner, app packaging, and icon generation
```

The test suite uses isolated temporary files. It covers scan criteria, old-cache filtering, protected paths, symlinks, replaced/changed files, cancellation, scan limits, duplicate roots, battery parsing, and basic live-metric bounds. It does not delete user files or exercise the full UI/Trash flow. GitHub Actions runs tests and packages a Universal app; packaging success alone does not establish UI correctness.

## Help shape the project

Contributions are welcome, particularly manual verification on different Mac models, translation improvements, battery compatibility fixtures, accessibility improvements, and cleanup safety tests. See the [roadmap](ROADMAP.md) and [contribution guide](CONTRIBUTING.md) for concrete starting points. Translation resources live in `Sources/MacPulseCore/Resources/{en,vi}.lproj/Localizable.strings`.

MacPulse was initially developed with assistance from OpenAI Codex. Generated changes remain subject to review, testing, and maintainer responsibility. MacPulse is an independent project with no claimed affiliation, sponsorship, or acceptance into an OpenAI program.

## License

MacPulse is available under the [MIT License](LICENSE).
