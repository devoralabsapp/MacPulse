# Changelog

## 1.1.0 — 2026-10-25

- Display RAM, swap, wired, compressed, and cached memory using 1024-based units, so 32 GiB appears as 32 GB. Keep file and storage sizes decimal.
- Label firmware design capacity separately from current full-charge capacity. Support nested `BatteryData` and legacy capacity fields; never substitute learned `Qmax` for design capacity.
- Show the full-charge/design capacity ratio without clipping values above 100%, and explain that it is not an Apple health diagnosis.
- Add English and Vietnamese resources and a persistent System default / English / Tiếng Việt language preference. Apply app text changes without discarding scan results or selection.
- Localize number/date output, app messages, and permission descriptions; include localization bundles in packaged apps.
- Add regression coverage for memory units, capacity sources, invalid registry values, translated messages, and translation catalog parity.
