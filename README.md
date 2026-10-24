# MacPulse

**Know what your Mac is doing. Choose what to clean up.**

[![macOS CI](https://github.com/devoralabsapp/MacPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/devoralabsapp/MacPulse/actions/workflows/ci.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-202b3c)
![Swift 6+](https://img.shields.io/badge/Swift-6%2B-orange)

[Tiếng Việt](README.vi.md) · [Contributing](CONTRIBUTING.md) · [Roadmap](ROADMAP.md) · [Report a bug](https://github.com/devoralabsapp/MacPulse/issues/new/choose)

MacPulse is a native macOS utility for monitoring CPU, memory, storage, battery, and network activity, with a file cleanup workflow that lets you review each candidate before moving it to Trash. Built with SwiftUI, AppKit, and IOKit, it runs locally without accounts, analytics, or third-party dependencies. The current app interface is in Vietnamese.

**Early development:** core tests and Universal builds have been verified locally. Visual UI checks and the full Trash workflow still need manual verification. Builds are ad hoc signed and are not notarized by Apple. See [verification notes](VERIFICATION.md) for the exact scope of validation.

## Why MacPulse?

System information should be understandable, and file cleanup should be a decision you control. MacPulse brings resource monitoring and file discovery into one app, makes battery charge available in **mAh when the hardware provides it**, and explains the limits of each measurement.

It does not treat an old modification date as proof that a file is unused. It shows candidates, their locations, sizes, and dates so you can decide what to keep.

## Features

| Area | What you can inspect |
| --- | --- |
| CPU | Total utilization, user/system/idle breakdown, core count, and a 60-sample history |
| Memory | Used, wired, compressed, cached memory, swap, and memory pressure when available |
| Storage | Capacity, used space, and available space on the volume containing your home folder |
| Battery | Charge percentage, remaining mAh, full-charge/design capacity, cycle count, estimated health, voltage, current, and time estimates when available |
| Network | Upload/download rates from physical network interfaces |
| File cleanup | Large files ≥100 MB, files unmodified for ≥180 days, and optional user cache/log files ≥30 days old |
| Menu bar | A live CPU readout and a compact resource summary |

Cleanup results support search, category filters, multiple selection, and **Reveal in Finder**. Nothing is selected automatically. A confirmation sheet lists the selected files before any Trash operation.

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

## Clean up files deliberately

1. Open **Dọn dẹp** (Cleanup), choose a folder, or use Downloads.
2. Optionally include old user caches and logs, then start the scan.
3. Inspect the results and reveal unfamiliar files in Finder.
4. Select files, choose **Chuyển vào Thùng rác** (Move to Trash), and review the confirmation list.
5. Restore files using Finder's **Put Back** if needed. Space is reclaimed only after you empty Trash yourself.

The scanner reads metadata, not file contents. It skips hidden files, symlinks, aliases, app/package contents, `node_modules`, designated system locations, and the user's Library outside Caches/Logs. Cloud-only iCloud items are skipped. Scans are cancellable and limited to 100,000 entries; use a smaller folder for larger collections.

Immediately before a Trash request, MacPulse rechecks the path, file identity, size, and modification time. Changed files are skipped. This check reduces stale-scan mistakes; it does not provide an atomic filesystem security guarantee. Caches may be recreated by their apps, and old files may still be important. Start with disposable files when testing the cleanup workflow.

Folder access follows macOS privacy permissions. If access is denied, select the folder again or review **System Settings → Privacy & Security → Files and Folders**. MacPulse does not require administrator privileges, empty Trash, force-purge RAM, uninstall apps, or modify system settings.

## How the measurements work

- **CPU:** Mach `host_statistics`, calculated from the difference between samples. The first CPU reading needs one sampling interval.
- **RAM:** `host_statistics64` and `vm.swapusage`. Memory usage is calculated from active, inactive, purgeable, file-backed, wired, and compressed pages. Values can differ from Activity Monitor because of timing and classification. Byte labels currently use decimal units, so 32 GiB is approximately 34.36 GB.
- **Disk:** Foundation volume capacity values for the home folder's volume. APFS sharing, snapshots, and purgeable space can produce differences from System Settings. Cleanup file sizes are logical sizes, not a promise of reclaimable physical space.
- **Battery:** IOPS for percentage/power state and `AppleSmartBattery` registry properties for raw charge when available. Registry properties depend on hardware/macOS. Missing values display `—`; percentage is never relabeled as mAh. Health is estimated full-charge capacity divided by design capacity, not an Apple diagnostic.
- **Network:** Physical interface byte counters, excluding VPN and bridge interfaces to avoid counting the same traffic twice.

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

Contributions are welcome, particularly manual verification on different Mac models, English localization, battery compatibility fixtures, accessibility improvements, and cleanup safety tests. See the [roadmap](ROADMAP.md) and [contribution guide](CONTRIBUTING.md) for concrete starting points.

MacPulse was initially developed with assistance from OpenAI Codex. Generated changes remain subject to review, testing, and maintainer responsibility. MacPulse is an independent project with no claimed affiliation, sponsorship, or acceptance into an OpenAI program.

## License

MacPulse is available under the [MIT License](LICENSE).
