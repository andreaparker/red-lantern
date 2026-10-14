# Security policy

## Report a vulnerability

Please use [GitHub’s private vulnerability reporting](https://github.com/andreaparker/red-lantern/security/advisories/new) for security issues. Include reproduction steps and the affected revision. Do not put passwords, tokens, or personal data in a public issue.

## Privacy and permissions

Red Lantern uses local system display APIs. It has no network client or server, accounts, analytics, credential storage, or third-party runtime dependencies.

- Preferences, including any entered coordinates, stay in local user defaults.
- The recovery helper runs with the same user privileges as the app. It accepts a bounded binary protocol on a private standard-input pipe.
- Mouse event monitors exist only while Quick Controls is open, to dismiss it on an outside click. They do not record or transmit input.
- No location permission or stored signing keys are required.

## Automated checks

The [GitHub Actions workflow](.github/workflows/checks.yml) runs on pushes and pull requests.

| Check | Scope |
| --- | --- |
| **Gitleaks 8.30.1** | Full Git history, standard rules, no comment-based secret exceptions. |
| **Clang Static Analyzer** | Core, Unix, and security checkers for both C files, including allocation and cleanup paths. |
| **AddressSanitizer + UndefinedBehaviorSanitizer** | 116 bounded/truncated recovery-protocol cases, with no display writes during those tests. |
| **Core regression tests** | 31 color, scheduling, settings, and screen-placement checks. |
| **Native build + signatures** | Build the application and verify its local ad-hoc signatures. |
| **Universal release package** | Compile Intel and Apple silicon binaries; check the ZIP’s file manifest, metadata, permissions, and private build paths; verify both architectures and signatures after extraction. |

Checkout is pinned to an immutable commit, and the scanner download is checksum-pinned. The workflow uses read-only repository permissions and requires no stored signing keys.

## Pre-publication review

The initial publication passed the checks above. Additional local checks included Swift compiler type checking with warnings treated as errors and a manual review of process launching, executable paths, preferences, file access, event monitors, display restoration, and publication contents.

Personal profiles, home-directory paths, local preferences, private logs, credentials, and signing keys were excluded from the publication payload. Project commit metadata uses a generic contributor identity.

## Scope and limitations

Release downloads are ad-hoc signed, not Developer ID signed or Apple-notarized. Signature verification checks bundle integrity, not the publisher’s verified identity or Apple malware screening. Release assets include a SHA-256 checksum for download verification. Follow [Apple’s per-app opening instructions](https://support.apple.com/en-us/102445) if macOS blocks a trusted download; do not disable Gatekeeper globally.

No findings were detected by the pre-publication automated checks. This is a scoped review, not an independent penetration test or a guarantee that the software is free of defects. The C analyzer does not analyze Swift; Swift was reviewed manually and checked with its compiler and regression tests.

Crash restoration requires a functioning recovery helper and display driver. It cannot recover from simultaneous helper failure or a system/driver crash. The app’s warmth labels are approximate visual presets and make no medical claims. Red Lantern does not disable PWM or temporal dithering, detect flashing content, or guarantee protection from neurological triggers. See [flicker limitations](docs/flicker.md).
