# Privacy Policy

AutoToggle is a privacy-first macOS menu bar app. This document explains how it handles your data.

## Data storage

- All rules, profiles, and logs are stored **locally** (SwiftData, under `~/Library/Application Support/`). They **never leave your device**.

## Network

- The 1.x offline line (1.3.0 and earlier) is **fully offline — it makes no network requests at all**. No telemetry, no analytics, no crash reporting, no third-party SDKs.

## Permissions

- **Accessibility**: used only to accurately determine the frontmost app so idle detection works. You can revoke it at any time in System Settings.
- **Apple Events (Automation)**: used only to send quit/hide instructions to apps you have explicitly added to your rules. It never controls apps outside your rules.

## Data collection

- **None.** AutoToggle does not collect, aggregate, or upload any usage data.

## Contact

- Questions and privacy concerns: see the project's GitHub Issues at <https://github.com/leogottadothebest/AutoToggle/issues>.
