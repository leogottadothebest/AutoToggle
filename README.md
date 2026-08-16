# AutoToggle

> Privacy-first, rule-driven app launcher & terminator for macOS

[English](README.md) · [中文](README.zh-CN.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue)](https://developer.apple.com/macos/)
[![Architecture](https://img.shields.io/badge/arch-Universal%20(Intel%20%2B%20Apple%20Silicon)-orange)](#)
[![Swift](https://img.shields.io/badge/swift-6.0-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

AutoToggle is a lightweight macOS menu bar app that **automatically launches** and **automatically quits** your applications based on custom rules. It supports both time-based schedules and idle detection, and all data is stored locally — the only network access is the built-in auto-update check.

## ✨ Features

- **🕐 Scheduled rules** — automatically launch or quit apps at specific times and weekdays
- **💤 Idle detection** — auto-quit or hide apps after they have been idle for a set duration
- **🛡️ Fake-idle detection** — intelligently recognizes audio playback, meetings, and similar scenarios to avoid false quits
- **📋 Menu bar icon + main window** — the main window opens on launch to manage rules and logs; closing the window hides the app from the Dock (it keeps running in the menu bar), and the menu bar icon is an always-on quick entry
- **🔌 Launch at login** — start automatically on sign-in, no manual steps
- **🔒 Privacy-first** — all data is stored locally with no data upload; the only network access is a periodic HTTPS check for updates
- **🇨🇳 Bilingual (Chinese / English)** — full Chinese UI plus a complete English translation, switchable in **Settings → Language** (a restart applies the change)
- **🔍 Smart app picker** — scans every app including Utilities, sorts by UI language (pinyin for Chinese, A–Z for English), with a clickable letter index and auto-focused search
- **⏰ Menu bar scheduled tasks** — upcoming scheduled launches/quits are shown right beside the managed apps; disabled tasks stay listed and can be toggled from the switch on the right
- **🔄 Auto-update** — built-in Sparkle 2 updater: checks on launch and via **Settings → About → Check for Updates…** (automatic checks can be toggled off); new versions download and install automatically
- **⌨️ Global hotkey** — press **⌥⌘P** anywhere to pause/resume all rules (requires Accessibility permission)

## 📥 Installation

### Download from GitHub Release

> ⚖️ **Version choice** — this project ships two release lines:
> - **1.x (e.g. 1.3.0)**: offline stable builds — no network access, no auto-update, the most secure option;
> - **2.x (e.g. 2.1.0)**: built-in Sparkle auto-update that periodically checks for new versions over the network (auto-check can be disabled in Settings).
>
> Choose 1.x for a fully offline environment, or 2.x for automatic updates.

1. Go to the [Releases](https://github.com/leogottadothebest/AutoToggle/releases) page
2. Download a `.dmg` file (e.g. `AutoToggle-2.1.0.dmg`)
3. Open the DMG and drag AutoToggle into the Applications folder
4. On first launch, right-click AutoToggle.app → **Open** to bypass Gatekeeper
5. Follow the prompts to grant **Accessibility** permission (optional, for more precise idle detection) — you can also manage it later in **Settings → Permissions**.

Once installed, AutoToggle checks for updates automatically on launch; you can also trigger it manually in **Settings → About → Check for Updates…**.

### Build from source

```bash
# Clone the repository
git clone https://github.com/leogottadothebest/AutoToggle.git
cd AutoToggle

# Install dependencies (XcodeGen required)
brew install xcodegen

# Create the stable self-signed signing certificate (keeps the Accessibility permission valid across rebuilds)
scripts/bootstrap-signing.sh

# Generate the Xcode project
xcodegen generate

# Build (Release)
xcodebuild -project AutoToggle.xcodeproj -scheme AutoToggle -configuration Release build

# The app is in the DerivedData directory
```

> The first build downloads the Sparkle updater framework via Swift Package Manager (network required once).

**Requirements**: Xcode 26.0+, macOS 14.0+

## 🎯 Usage

### Create a scheduled rule

1. Open the main window (it opens automatically on launch; or click the menu bar icon → **Main Window**) and go to the **Apps** tab
2. Click **Add Rule**
3. Search for and select the target app
4. Choose **Scheduled Launch** or **Scheduled Quit**
5. Set the trigger time (HH:mm) and the days (daily / weekdays / weekends / custom)
6. Click **Save**

### Create an idle rule

1. Enter rule editing as above
2. Choose **Idle Quit** or **Idle Hide**
3. Set the idle duration (pick a preset or type a custom number of minutes)
4. Click **Save**

> 💡 **Tip**: Apps that are playing music or in a video call will not be closed automatically.

### Manage rules

- **Enable / Disable**: toggle the switch directly in the rule list
- **Edit**: double-click a rule row
- **Delete**: swipe left on a rule row, or delete from the edit screen

## ❓ FAQ / Troubleshooting

**"AutoToggle" can't be opened because it can't be verified**

AutoToggle is signed with a self-signed certificate (not Apple-notarized). On first launch, right-click the app → **Open**, or run `xattr -dr com.apple.quarantine /Applications/AutoToggle.app`. You can verify the download integrity against the SHA-256 checksum (the `.sha256` file on the release page).

**Accessibility is granted but the app still shows "not authorized"**

macOS caches the grant for a running process. Restart AutoToggle. If it still fails, run `tccutil reset Accessibility com.autotoggle.app`, re-grant it in System Settings, then restart again.

**Why did my app get quit or hidden?**

An idle rule fired. Check **Settings → Logs** for an "idle quit"/"idle hide" entry. Apps that are playing audio or in a call are protected by fake-idle detection.

**Why won't my app quit?**

AutoToggle quits apps in three tiers (AppleScript → terminate → force). A first-launch "unsaved changes" dialog can block the graceful path. Check Logs to see which tier was used.

**My app doesn't appear in the picker**

The picker scans `/Applications`, `/Applications/Utilities`, and `/System/Applications`. Apps installed elsewhere are not indexed.

## 🏗️ Architecture

```
AutoToggle/
├── AutoToggleApp.swift         # @main entry (App scene + MenuBarExtra)
├── AppDelegate.swift           # native NSWindow + NSHostingView main window
├── AppDependencies.swift       # @MainActor centralized dependency injection
├── Info.plist / AutoToggle.entitlements
├── Managers/                   # business logic (@MainActor)
│   ├── RuleManager             # SwiftData CRUD
│   ├── ScheduleManager         # scheduling engine
│   ├── AppMonitorManager       # NSWorkspace lifecycle monitoring
│   ├── IdleDetectorManager     # idle detection + fake-idle detection
│   ├── AppActionManager        # app launch/quit (three-tier graceful fallback)
│   ├── MenuBarManager          # menu bar state management
│   ├── LogManager              # logging + retention policy
│   ├── ProfileManager          # rule import / export
│   ├── PermissionManager       # permission checks
│   ├── AppearanceManager       # appearance / theming
│   ├── SleepPreventionManager  # sleep-prevention assertions during scheduled actions
│   ├── UpdateManager           # Sparkle auto-update
│   └── FocusedAppProvider / IdleDecisionEngine / SystemIdleProvider
├── Models/                     # SwiftData (AppRule / LogEntry / Profile / AppInfo / TimeTrigger)
├── Views/
│   ├── MainWindow/             # main window (Overview / App / Settings / Logs)
│   ├── MenuBar/                # menu bar panel
│   ├── Settings/               # rule editing components
│   └── Onboarding/             # permission onboarding
├── Utilities/                  # helpers (BundleHelper / AppIconProvider / AppSortHelper / LanguageManager)
└── Resources/                  # Assets.xcassets / Localizable.xcstrings
```

### App quit fallback strategy

```
1️⃣  AppleScript quit → most graceful (saves data)
2️⃣  NSRunningApplication.terminate() → standard quit
3️⃣  forceTerminate() → last resort (re-resolves PID by bundle ID to avoid killing a recycled PID)
```

## 📋 Roadmap

- [ ] WiFi / Bluetooth / power-state triggers
- [ ] Scene mode (one-click switch between work/life app layouts)
- [ ] Shortcuts integration
- [ ] App usage statistics
- [ ] Rule template marketplace

## 📄 License

MIT License © 2026 AutoToggle contributors

[Privacy Policy](PRIVACY.md) · [Contributing](CONTRIBUTING.md) · [Code of Conduct](CODE_OF_CONDUCT.md)

---

<p align="center">
  <sub>Built with ❤️ for macOS</sub>
</p>
