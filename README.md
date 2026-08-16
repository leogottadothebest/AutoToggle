# AutoToggle

> Privacy-first, rule-driven app launcher & terminator for macOS

[English](README.md) · [中文](README.zh-CN.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue)](https://developer.apple.com/macos/)
[![Architecture](https://img.shields.io/badge/arch-Universal%20(Intel%20%2B%20Apple%20Silicon)-orange)](#)
[![Swift](https://img.shields.io/badge/swift-6.0-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

AutoToggle is a lightweight macOS menu bar app that **automatically launches** and **automatically quits** your applications based on custom rules. It supports both time-based schedules and idle detection, and all data is stored locally — no network required.

## ✨ Features

- **🕐 Scheduled rules** — automatically launch or quit apps at specific times and weekdays
- **💤 Idle detection** — auto-quit or hide apps after they have been idle for a set duration
- **🛡️ Fake-idle detection** — intelligently recognizes audio playback, meetings, and similar scenarios to avoid false quits
- **📋 Menu bar icon + main window** — the main window opens on launch to manage rules and logs; closing the window hides the app from the Dock (it keeps running in the menu bar), and the menu bar icon is an always-on quick entry
- **🔌 Launch at login** — start automatically on sign-in, no manual steps
- **🔒 Privacy-first** — all data is stored locally, with no network requests and no data upload
- **🇨🇳 Bilingual (Chinese / English)** — full Chinese UI plus a complete English translation, switchable in **Settings → Language** (a restart applies the change)
- **🔍 Smart app picker** — scans every app including Utilities, sorts by UI language (pinyin for Chinese, A–Z for English), with a clickable letter index and auto-focused search
- **⏰ Menu bar scheduled tasks** — upcoming scheduled launches/quits are shown right beside the managed apps; disabled tasks stay listed and can be toggled from the switch on the right

## 📥 Installation

### Download from GitHub Release

1. Go to the [Releases](https://github.com/leogottadothebest/AutoToggle/releases) page
2. Download the latest `.dmg` file (e.g. `AutoToggle-1.3.0.dmg`)
3. Open the DMG and drag AutoToggle into the Applications folder
4. On first launch, right-click AutoToggle.app → **Open** to bypass Gatekeeper
5. Follow the prompts to grant **Accessibility** permission (optional, for more precise idle detection) — you can also manage it later in **Settings → Permissions**.

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

# Build (Release) — uses scripts/build.sh (unlocks the signing keychain, runs xcodegen, builds, verifies)
scripts/build.sh

# The app is in build/DerivedData/Build/Products/Release/AutoToggle.app
```

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

## 🏗️ Architecture

```
AutoToggle/
├── AutoToggleApp.swift         # @main entry (empty App scene; window + menu bar created in AppKit)
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

## ❓ FAQ / Troubleshooting

**"AutoToggle can't be opened because it's from an unidentified developer"**
This is expected for a self-signed (un-notarized) build. On first launch, **right-click AutoToggle.app → Open** to bypass Gatekeeper. You can also verify the DMG's SHA-256 (the `.sha256` file ships alongside each Release) and then run `xattr -dr com.apple.quarantine /Applications/AutoToggle.app` to clear the flag permanently.

**Accessibility is granted in System Settings, but the app still says "not authorized"**
macOS caches the permission for the running process. Grant it, then **restart AutoToggle**. If it still doesn't stick, run `tccutil reset Accessibility com.autotoggle.app`, then remove and re-add AutoToggle under System Settings → Privacy & Security → Accessibility.

**Why was an app quit automatically?**
An idle rule fired: the app was idle longer than its configured threshold, so it was quit/hidden. Disable or delete the corresponding idle rule in the Apps tab.

**Why won't a target app quit?**
The three-tier fallback (AppleScript → terminate → forceTerminate) can fail if the target app is showing a modal like "Save changes?", or if AutoToggle lacks Automation permission. Dismiss the dialog, and confirm AutoToggle is allowed to control the app under System Settings → Privacy & Security → Automation.

**I'm on 1.2.0 — how do I upgrade to 1.3.0?**
The 1.x offline line has no auto-update. Download `AutoToggle-1.3.0.dmg` from the Releases page and reinstall manually.

## 📄 License

MIT License © 2026 leogottadothebest

---

<p align="center">
  <sub>Built with ❤️ for macOS</sub>
</p>
