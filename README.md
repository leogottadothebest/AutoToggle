# AutoToggle

> Privacy-first, rule-driven app launcher & terminator for macOS

[English](README.md) · [中文](README.zh-CN.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2026.0%2B-blue)](https://developer.apple.com/macos/)
[![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon%20only-orange)](#)
[![Swift](https://img.shields.io/badge/swift-6.0-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

AutoToggle is a lightweight macOS menu bar app that **automatically launches** and **automatically quits** your applications based on custom rules. It supports both time-based schedules and idle detection, and all data is stored locally — no network required.

## ✨ Features

- **🕐 Scheduled rules** — automatically launch or quit apps at specific times and weekdays
- **💤 Idle detection** — auto-quit or hide apps after they have been idle for a set duration
- **🛡️ Fake-idle detection** — intelligently recognizes audio playback, meetings, and similar scenarios to avoid false quits
- **📋 Menu bar icon + main window** — the menu bar icon is an always-on quick entry, while the main window manages rules and logs
- **🔌 Launch at login** — start automatically on sign-in, no manual steps
- **🔒 Privacy-first** — all data is stored locally, with no network requests and no data upload
- **🇨🇳 Native Chinese** — full Chinese UI, optimized for WeChat / DingTalk / Feishu and other domestic apps

## 📥 Installation

### Download from GitHub Release

1. Go to the [Releases](https://github.com/leogottadothebest/AutoToggle/releases) page
2. Download the latest `.dmg` file (e.g. `AutoToggle-1.0.0.dmg`)
3. Open the DMG and drag AutoToggle into the Applications folder
4. On first launch, right-click AutoToggle.app → **Open** to bypass Gatekeeper
5. Follow the prompts to grant **Accessibility** permission (optional, for more precise idle detection)

### Build from source

```bash
# Clone the repository
git clone https://github.com/leogottadothebest/AutoToggle.git
cd AutoToggle

# Install dependencies (XcodeGen required)
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Build
xcodebuild -project AutoToggle.xcodeproj -scheme AutoToggle -configuration Release build

# The app is in the DerivedData directory
```

**Requirements**: Xcode 26.0+, macOS 26.0+

## 🎯 Usage

### Create a scheduled rule

1. Click the menu bar icon → **Settings** → **Rules** tab
2. Click **Add Rule**
3. Search for and select the target app
4. Choose **Scheduled Launch** or **Scheduled Quit**
5. Set the trigger time (HH:mm) and the days (daily / weekdays / weekends / custom)
6. Click **Save**

### Create an idle rule

1. Enter rule editing as above
2. Choose **Idle Quit** or **Idle Hide**
3. Set the idle duration (1 minute to 2 hours)
4. Click **Save**

> 💡 **Tip**: Apps that are playing music or in a video call will not be closed automatically.

### Manage rules

- **Enable / Disable**: toggle the switch directly in the rule list
- **Edit**: double-click a rule row
- **Delete**: swipe left on a rule row, or delete from the edit screen

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
│   └── FocusedAppProvider / IdleDecisionEngine / SystemIdleProvider
├── Models/                     # SwiftData (AppRule / LogEntry / Profile / AppInfo / TimeTrigger)
├── Views/
│   ├── MainWindow/             # main window (Overview / App / Settings / Logs)
│   ├── MenuBar/                # menu bar panel
│   ├── Settings/               # rule editing components
│   └── Onboarding/             # permission onboarding
├── Utilities/                  # helpers (BundleHelper / AppIconProvider)
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

MIT License © 2026 leogottadothebest

---

<p align="center">
  <sub>Built with ❤️ for macOS</sub>
</p>
