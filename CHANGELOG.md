# Changelog

## 1.4.0 — 2026-10-25

- Redesign the sidebar, page headers, metric cards, panels, and file selection highlights with consistent spacing, typography, and semantic colors.
- Add Ocean, Forest, Violet, and Graphite palettes with System default, Light, and Dark appearance modes. Remove the forced light appearance.
- Add a quick appearance menu in the main window and visual palette previews in Settings; organize preferences into Appearance and General tabs.
- Persist appearance preferences across scenes without resetting resource history, scan results, or selected files. Theme app-owned confirmation sheets and the menu bar popup.
- Preserve semantic cleanup risk colors across palettes, improve disabled button styling, and localize appearance controls in English and Vietnamese.
- Add contrast checks for text, buttons, chart lines, selected navigation, and risk badges across all eight palette/mode combinations, plus system-mode resolution and localization checks.

## 1.3.0 — 2026-10-25

- Add a Network page with live upload/download rates, a 60-sample chart, per-interface activity/rates, chart peaks, and observed session totals.
- Add a saved KB/s–MB/s vs. Kbps–Mbps preference, plus optional live speeds in the menu bar and rates in its popup panel.
- Replace 32-bit `getifaddrs` byte counters with `NET_RT_IFLIST2` 64-bit counters. Calculate deltas per interface using monotonic elapsed time, excluding virtual interfaces.
- Rebaseline on first samples, read failure, counter resets, interface changes, and reconnection; preserve chart gaps and distinguish unavailable readings from zero traffic.
- Add regression tests for rate calculation, elapsed time, counters above 4 GiB, reconnect/reset behavior, virtual-interface exclusion, byte/bit formatting, malformed buffers, and live kernel reads without generating traffic.

## 1.2.0 — 2026-10-25

- Withhold the battery-health estimate when full-charge and design references conflict. Preserve both raw readings and show the macOS-reported condition separately; do not invent design capacity or silently clamp to 100%.
- Assess cleanup candidates as lower risk, review first, or avoid cleanup, with a visible reason, risk filters, counts, and an explicit lower-risk selection action.
- Restrict lower-risk recommendations to recognized old cache/log formats in standard user folders, with checks for recent activity, open files, and running owners. Incomplete inspection falls back to review-only.
- Block detected cloud data, databases, security material, backups, incomplete downloads, locked/unwritable files, and multiple links from selection.
- Refresh usage information before moving a batch and reassess each file. Skip blocked or downgraded lower-risk items, retain the confirmation sheet, and move only to Trash.
- Add bilingual explanations and regression coverage for assessment rules, blocked validation, open-file parsing, a disposable open-file fixture, and inconsistent battery readings.

## 1.1.0 — 2026-10-25

- Display RAM, swap, wired, compressed, and cached memory using 1024-based units, so 32 GiB appears as 32 GB. Keep file and storage sizes decimal.
- Label firmware design capacity separately from current full-charge capacity. Support nested `BatteryData` and legacy capacity fields; never substitute learned `Qmax` for design capacity.
- Show the full-charge/design capacity ratio without clipping values above 100%, and explain that it is not an Apple health diagnosis.
- Add English and Vietnamese resources and a persistent System default / English / Tiếng Việt language preference. Apply app text changes without discarding scan results or selection.
- Localize number/date output, app messages, and permission descriptions; include localization bundles in packaged apps.
- Add regression coverage for memory units, capacity sources, invalid registry values, translated messages, and translation catalog parity.
