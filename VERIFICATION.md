# Verification notes

Local verification on 25 October 2026:

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

- Automated UI inspection was unavailable because permission to control the app was not granted. Screens, folder selection, settings, menu bar behavior, and the complete Trash/restore workflow have not been visually verified.
- Tests ran on the `x86_64` host. The `arm64` slice was cross-compiled, not run natively on Apple Silicon during this verification.
- No user files were cleaned. The test suite uses isolated temporary fixtures and does not exercise a real Trash operation.
- The app is ad hoc signed, not Apple-notarized. Build and unit test success do not establish production readiness.

Reproduce the automated checks with `bash scripts/test.sh` and `bash scripts/build-app.sh --universal`. Use disposable files for manual cleanup checks. GitHub Actions results, when available, are separate evidence from these local checks.
