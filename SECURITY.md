# Security policy

MacPulse is in early development. Security fixes currently target the default branch; no stable release support window is promised.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/devoralabsapp/MacPulse/security/advisories/new) to share a finding privately with the maintainer. If that option is unavailable, open an issue asking for a private reporting channel without publishing exploit details or personal data. Avoid public reports that expose a path to deleting or moving unintended files.

A useful report includes the affected commit, macOS version, a minimal reproduction using disposable files, expected behavior, and observed impact. Redact home paths, usernames, serial numbers, and unrelated file names. Do not attach credentials or personal documents.

## Areas that need care

- Path containment, protected directories, symlinks, and file replacement between scan and Trash operations.
- macOS folder permissions and the behavior of external, network, and cloud-backed volumes.
- Battery registry data with missing fields, unexpected types, or different units.
- Packaging and distribution integrity.

Cleanup validation is a preflight check, not an atomic filesystem security boundary. The app is not designed for hostile filesystems or use as a privileged cleanup service. It never requires administrator privileges or empties Trash. Source builds use an ad hoc signature; Developer ID signing and notarization are not configured.
