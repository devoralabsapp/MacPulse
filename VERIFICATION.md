# Verification notes

Local verification on 25 October 2026:

## Version 1.5.0: iPhone and iPad

- 63 shared/macOS tests pass locally, without failures or skips. The 11 added cases cover process CPU baselines/normalization and disposable file recovery, including restore collisions, changed files, symlinked parents, sensitive files, cancellation, unknown recovery folders, path traversal, and unexpected entry contents.
- On dedicated Simulators, 12 unit/integration tests plus the English adaptive-navigation/persisted-appearance UI test pass on iPhone 17 Pro (iOS 26.5), iPad Pro 11-inch M5 (iPadOS 26.5), and iPhone 15 Pro (iOS 17.0). An additional Vietnamese/light-theme/navigation UI test passes on iPhone 17 Pro.
- Actual XCTest screenshots of iPhone/iPad Overview and Appearance were visually reviewed. UI tests change palettes/mode, relaunch to check saved appearance, and navigate to Network and Files. They do not grant access to or delete real user files.
- Release Simulator and unsigned arm64 device builds pass. Packaging verifies both iPhone/iPad device families, English/Vietnamese mobile translations, privacy manifest, and MIT License. The generated 1024-pixel iOS icon is opaque RGB.
- The macOS Universal app still builds and passes signature, architecture, and resource checks after separating platform-specific sources.
- Physical-device installation/signing, battery/network readings on hardware, external Files/iCloud providers, accessibility/Dynamic Type, and the full document-picker/Quick Look UI flow need manual verification. Recovery operations are verified with isolated local fixtures, not a cloud provider. No TestFlight/App Store submission or signed iOS distribution was performed.

## Version 1.4.0 update

- 52 tests pass with no failures or skips locally. Existing monitoring, battery, formatting, localization, and cleanup checks remain green.
- New checks cover System default versus explicit appearance overrides and contrast across four palettes in light/dark modes: body/secondary text and button/navigation labels at least 4.5:1, chart lines at least 3:1, and cleanup risk text/badges at least 4.5:1. Risk colors are independent of the selected accent palette.
- Offscreen `NSHostingView` renders of the production SwiftUI views with deterministic sample data were visually reviewed: Overview at 1220 × 840 and 1080 × 730, English/Vietnamese, all four palettes, appearance previews, cleanup tables with a selected row, Network, and Battery. This checks layout and colors; it does not test user interaction or capture a running app. Native tab/header rendering depends on the hosting window.
- The Universal 1.4.0 bundle includes arm64 and x86_64 slices. Ad hoc signature verification, bundled translations, Info.plist, and ZIP integrity checks pass.
- Interactive theme selection/persistence, live macOS automatic appearance changes, native Settings tabs, menu bar controls, folder selection, and the full Trash/restore flow still need manual verification. No user files were cleaned.

## Version 1.3.0 update

- 48 tests pass with no failures or skips locally. Live `NET_RT_IFLIST2` sampling successfully read physical-interface counters and observed upload/download traffic without generating test requests.
- Network tests cover actual elapsed time, initial baselines, per-interface aggregation, virtual-interface exclusion, counters crossing 4 GiB, counter reset, reconnect, read failure, non-increasing/invalid clocks, byte/bit conversions, localized formatting, and malformed/truncated kernel messages.
- The new UI includes a Network page, chart, interface table, observed session totals, menu bar speeds, and saved unit/display preferences in both languages.
- Direct visual verification of the new chart, status item, and controls remains outstanding. Network activity flags are not Internet-reachability checks; observed session totals exclude unsampled intervals.

## Version 1.2.0 update

- 35 tests pass with no failures. The open-file integration test observed its own disposable open fixture through unprivileged `lsof`; no user files were moved or deleted.
- Assessment tests cover recognized standard cache/log paths, recent access/creation, incomplete checks, open files, running owners, cloud data, databases, security material, backups, partial downloads, locks/multiple links, and fake cache-folder/category hints.
- Blocked candidates fail the core Trash validation check. New tests verify that risk increases when usage changes, and that inconsistent battery references produce no health estimate or fabricated 100%.
- English/Vietnamese resources have matching keys and format parameters. Battery and cleanup explanations are available in both languages.
- Risk labels remain heuristic, and process inspection is a point-in-time user-level snapshot. Manual checks of the new risk controls, live language switching, and the full Trash/restore flow are still outstanding.

## Version 1.1.0 update

- 20 core tests pass, including regression tests that format 8/16/32/64/128 GiB RAM as the corresponding macOS-style GB values in both languages, while preserving decimal file sizes.
- Battery capacity fixtures keep full-charge capacity and firmware design capacity separate, support nested `BatteryData`, and reject percentage/boolean/invalid values as design mAh. The estimated full-charge/design ratio is no longer clipped at 100%.
- English and Vietnamese catalogs contain the same 171 keys and matching format placeholders. Dynamic messages can rerender in the selected language without rescanning.
- App packaging now includes the localization resource bundle and English/Vietnamese permission descriptions. `scripts/verify-app.swift` checks the translations inside the built app, independently of the build directory.
- Manual verification of the live language selector, window layout, and complete Trash/restore flow remains outstanding.

## Initial version verification

| Check | Result |
| --- | --- |
| Debug build | Passed |
| Release Universal build | Passed; `x86_64` and `arm64` slices, macOS 14.0 deployment target |
| `codesign --verify --deep --strict` | Passed with a local ad hoc signature |
| Info.plist validation | Passed |
| Shell syntax checks | Passed for the test and packaging scripts |
| ICNS icon | Readable by `sips`, including 1024 × 1024 and smaller/Retina representations |
| Core test suite | 11 tests passed, 0 failures |
| Live sampling | CPU, memory, disk, battery percentage, and raw mAh were available on the test machine |
| ZIP integrity | Archive contents and integrity verified |

Tests cover battery percentage-vs-mAh parsing, raw/legacy/missing capacity data, basic metric bounds, scan size/age criteria, old-cache filtering, protected paths, symlinks, hidden files, app bundles, duplicate roots, cancellation, scan limits, changed files, and symlinked parents.

## Limits of this verification

- Earlier direct UI automation for macOS was unavailable because permission to control the app was not granted. Version 1.4.0 adds offscreen render checks of the app’s own view code with sample data. These do not verify interactive settings, menu bar behavior, folder selection, or the complete Trash/restore workflow.
- Tests ran on the `x86_64` host. The `arm64` slice was cross-compiled, not run natively on Apple Silicon during this verification.
- No user files were cleaned. The test suite uses isolated temporary fixtures and does not exercise a real Trash operation.
- The app is ad hoc signed, not Apple-notarized. Build and unit test success do not establish production readiness.

Reproduce the automated checks with `bash scripts/test.sh` and `bash scripts/build-app.sh --universal`. Use disposable files for manual cleanup checks. GitHub Actions results, when available, are separate evidence from these local checks.
