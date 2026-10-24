# Roadmap

MacPulse is a new project. These are proposed milestones, not shipped features or delivery promises. Priorities can change based on issues and compatibility reports.

## Verify the foundation

- [ ] Complete manual checks of all screens, menu bar behavior, settings, folder selection, and Trash/restore using disposable fixtures.
- [ ] Run the app and tests natively on Apple Silicon and Intel, including macOS 14 and newer supported versions.
- [ ] Document denied-permission, missing-battery-data, no-battery, and external-volume behavior.
- [ ] Add battery fixtures covering more hardware and registry variations, with identifiers removed.
- [ ] Add targeted tests for partial Trash failures and files changing during the operation.

## Make the app accessible to more users

- [ ] Extract hard-coded UI strings into a localization catalog.
- [ ] Add an English interface alongside Vietnamese.
- [ ] Audit VoiceOver, keyboard focus, contrast, and text scaling.
- [ ] Improve memory unit labels and explain pressure vs. utilization in the UI.
- [ ] Add genuine screenshots after manual UI verification.

## Improve everyday use

- [ ] Add configurable scan thresholds and a scan summary that separates logical size from allocated size.
- [ ] Investigate duplicate detection with explicit content comparison and separate confirmation.
- [ ] Explore per-process resource information without adding privileged helpers.
- [ ] Profile CPU, memory, and energy overhead during idle monitoring and large scans.

## Prepare wider distribution

- [ ] Add Developer ID signing and Apple notarization when a maintainer signing identity is available.
- [ ] Publish tested releases with checksums and documented compatibility.
- [ ] Keep CI, contributor documentation, and cleanup regression coverage up to date.
