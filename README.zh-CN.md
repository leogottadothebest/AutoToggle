# AutoToggle

> macOS 应用自动开关管家 — 隐私优先、规则驱动

[English](README.md) · [中文](README.zh-CN.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2026.0%2B-blue)](https://developer.apple.com/macos/)
[![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon%20only-orange)](#)
[![Swift](https://img.shields.io/badge/swift-6.0-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

AutoToggle 是一款轻量级 macOS 菜单栏应用，通过自定义规则**自动启动**和**自动退出**你的应用程序。它支持按时间计划和闲置检测两种触发方式，所有数据仅存储在本地，无需联网。

## ✨ 功能

- **🕐 定时规则** — 按具体时间和星期自动启动或退出应用
- **💤 闲置检测** — 应用闲置指定分钟后自动退出或隐藏
- **🛡️ 假闲置检测** — 智能识别音频播放、会议等场景，避免误关
- **📋 菜单栏图标 + 主窗口** — 主窗口启动即打开，集中管理规则与日志；关闭窗口后应用从 Dock 消失（继续驻留菜单栏），菜单栏图标作为常驻快速入口
- **🔌 开机自启** — 登录时自动启动，无需手动操作
- **🔒 隐私优先** — 所有数据存储在本地，无网络请求，无数据上传
- **🇨🇳 中文原生** — 全中文界面，对微信/钉钉/飞书等国内应用优化
- **🔍 智能应用选择器** — 完整扫描含实用工具在内的所有应用，按界面语言排序（中文按拼音、英文按字母），支持点击字母表快速导航
- **⏰ 菜单栏显示定时任务** — 即将触发的定时启动/退出与被管理应用并列展示；已关闭的定时任务仍显示，可在右侧开关一键切换

## 📥 安装

### 从 GitHub Release 下载

1. 前往 [Releases](https://github.com/leogottadothebest/AutoToggle/releases) 页面
2. 下载最新的 `.dmg` 文件（如 `AutoToggle-1.1.0.dmg`）
3. 打开 DMG，将 AutoToggle 拖入「应用程序」文件夹
4. 首次启动时，右键点击 AutoToggle.app →「打开」以绕过 Gatekeeper
5. 根据引导授予「辅助功能」权限（可选，用于更精确的闲置检测），之后也可在「设置 → 权限」中查看或重新请求。

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/leogottadothebest/AutoToggle.git
cd AutoToggle

# 安装依赖（需要 XcodeGen）
brew install xcodegen

# 生成稳定的自签名签名证书（保证辅助功能授权在每次重建后不失效）
scripts/bootstrap-signing.sh

# 生成 Xcode 项目
xcodegen generate

# 构建（Release）
xcodebuild -project AutoToggle.xcodeproj -scheme AutoToggle -configuration Release build

# 成品在 DerivedData 目录中
```

**要求**: Xcode 26.0+, macOS 26.0+

## 🎯 使用指南

### 创建定时规则

1. 打开主窗口（启动时自动弹出；或点击菜单栏图标 → **主界面**）并进入 **App** 选项卡
2. 点击 **添加规则**
3. 搜索并选择目标应用
4. 选择 **定时启动** 或 **定时退出**
5. 设置触发时间（时:分）和日期（每天/工作日/周末/自定义）
6. 点击 **保存**

### 创建闲置规则

1. 同上进入规则编辑
2. 选择 **闲置退出** 或 **闲置隐藏**
3. 设置闲置时长（选择预设或手动输入任意分钟数）
4. 点击 **保存**

> 💡 **提示**: 正在播放音乐、视频会议的应用程序不会被自动关闭。

### 管理规则

- **启用/禁用**: 在规则列表中直接切换开关
- **编辑**: 双击规则行
- **删除**: 在规则行上向左滑动 ∨ 进入编辑界面后点击删除

## 🏗️ 技术架构

```
AutoToggle/
├── AutoToggleApp.swift         # @main 入口（App 场景 + MenuBarExtra）
├── AppDelegate.swift           # 原生 NSWindow + NSHostingView 主窗口
├── AppDependencies.swift       # @MainActor 集中依赖注入
├── Info.plist / AutoToggle.entitlements
├── Managers/                   # 业务逻辑（@MainActor）
│   ├── RuleManager             # SwiftData CRUD
│   ├── ScheduleManager         # 定时调度引擎
│   ├── AppMonitorManager       # NSWorkspace 生命周期监控
│   ├── IdleDetectorManager     # 闲置检测 + 假闲置判断
│   ├── AppActionManager        # 应用启停（三级优雅降级）
│   ├── MenuBarManager          # 菜单栏状态管理
│   ├── LogManager              # 日志 + 保留策略
│   ├── ProfileManager          # 规则导入/导出
│   ├── PermissionManager       # 权限检查
│   ├── AppearanceManager       # 外观/配色
│   ├── SleepPreventionManager  # 防睡眠断言（执行定时动作时防止系统休眠）
│   └── FocusedAppProvider / IdleDecisionEngine / SystemIdleProvider
├── Models/                     # SwiftData（AppRule / LogEntry / Profile / AppInfo / TimeTrigger）
├── Views/
│   ├── MainWindow/             # 主窗口（Overview / App / Settings / Logs）
│   ├── MenuBar/                # 菜单栏面板
│   ├── Settings/               # 规则编辑组件
│   └── Onboarding/             # 权限引导
├── Utilities/                  # 工具类（BundleHelper / AppIconProvider / AppSortHelper）
└── Resources/                  # Assets.xcassets / Localizable.xcstrings
```

### 应用退出降级策略

```
1️⃣  AppleScript quit → 最优雅（保存数据）
2️⃣  NSRunningApplication.terminate() → 标准退出
3️⃣  forceTerminate() → 最后手段（按 bundleID 重查 PID，避免 PID 复用误杀）
```

## 📋 待实现功能

- [ ] WiFi/蓝牙/电源条件触发
- [ ] 场景模式（一键切换工作/生活应用布局）
- [ ] Shortcuts 集成
- [ ] 应用使用统计
- [ ] 规则模板市场

## 📄 许可

MIT License © 2026 leogottadothebest

---

<p align="center">
  <sub>Built with ❤️ for macOS</sub>
</p>
