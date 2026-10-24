# Contributing to MacPulse

Small, focused contributions are welcome. For a substantial change, open an issue describing the problem and proposed behavior first.

## Set up

Use macOS 14+ with Swift 6+ through Xcode or Command Line Tools:

```sh
git clone https://github.com/devoralabsapp/MacPulse.git
cd MacPulse
bash scripts/test.sh
bash scripts/build-app.sh
open dist/MacPulse.app
```

Open `Package.swift` in Xcode for editing. No external packages or API keys are needed.

## Useful first contributions

- Try the packaged app on your Mac and report hardware/macOS compatibility without sharing serial numbers.
- Improve VoiceOver labels, keyboard navigation, or text layout.
- Improve English/Vietnamese translations in `Sources/MacPulseCore/Resources/{en,vi}.lproj/Localizable.strings`, keeping keys and format placeholders aligned.
- Add anonymized battery fixtures for missing/unsupported capacity values.
- Extend cleanup tests for stale files, permission failures, and cloud placeholders.

See [ROADMAP.md](ROADMAP.md) for planned work. Planned work is not a claim that these features already exist.

## Before opening a pull request

1. Describe the problem and the behavior after your change.
2. Keep system sampling in `MacPulseCore`; keep app UI and interactions in `MacPulse`.
3. Run `bash scripts/test.sh` and `bash scripts/build-app.sh`.
4. For UI changes, include a screenshot and your manual verification steps, using disposable files for cleanup tests.
5. For cleanup changes, add tests that address a meaningful failure mode. Preserve review-before-Trash behavior and revalidation of scanned candidates.

Do not use personal files as deletion fixtures. Do not attach unredacted paths, battery serial numbers, account details, or credentials. Never add automatic permanent deletion, permission escalation, shell-based deletion, or unsupported claims of reclaimed disk space.

AI-assisted contributions are welcome. Review the generated code, disclose material assistance when useful for review, and provide the same evidence you would for any other change. Submit only work you have the right to contribute; accepted contributions are distributed under this repository's MIT License.

## Reporting bugs

Use the issue templates. Include the expected behavior, observed behavior, reproduction steps, macOS version, processor architecture, and relevant redacted output. For cleanup bugs, reproduce with a minimal disposable folder if possible.

For security-sensitive findings, follow [SECURITY.md](SECURITY.md). Please keep discussions respectful and focused on the problem.
