import AppKit
import Foundation

/// 应用生命周期监控管理器
/// 使用 NSWorkspace 通知追踪应用的启动、终止、激活和去激活事件
@MainActor
@Observable
final class AppMonitorManager {
    // MARK: - 公开属性

    /// 当前所有运行中的普通应用（排除后台代理应用）
    private(set) var runningApps: [AppInfo] = []

    /// 最前台活跃应用
    private(set) var frontmostApp: AppInfo?

    /// 前台应用切换回调（Bundle ID → Void）
    var onFrontmostAppChanged: ((String) -> Void)?

    /// 应用启动回调（Bundle ID → Void）。
    /// 用于在任意应用（含定时/后台启动）启动时重置其闲置基线，避免陈旧活跃时间导致闲置规则立即误触发。
    var onAppLaunched: ((String) -> Void)?

    // MARK: - 私有属性

    /// NSWorkspace 通知观察者 tokens
    private var observerTokens: [NSObjectProtocol] = []

    // MARK: - 公开方法

    /// 启动应用监控
    func startMonitoring() {
        // 初始扫描
        refreshRunningApps()

        let nc = NSWorkspace.shared.notificationCenter

        // 应用启动
        let launchToken = nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { @Sendable notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            let name = app?.localizedName
            let path = app?.bundleURL?.path

            Task { @MainActor [weak self] in
                guard let self, let bundleID else { return }
                let info = AppInfo(bundleID: bundleID, displayName: name ?? String(localized: "未知应用"), appPath: path)
                if !self.runningApps.contains(where: { $0.bundleID == info.bundleID }) {
                    self.runningApps.append(info)
                }
                // 应用启动即开启新的闲置周期（见 onAppLaunched 文档）
                self.onAppLaunched?(bundleID)
            }
        }
        observerTokens.append(launchToken)

        // 应用终止
        let terminateToken = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { @Sendable notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier ?? ""

            Task { @MainActor [weak self] in
                self?.runningApps.removeAll { $0.bundleID == bundleID }
            }
        }
        observerTokens.append(terminateToken)

        // 应用激活（变为前台）
        let activateToken = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { @Sendable notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            let name = app?.localizedName
            let path = app?.bundleURL?.path

            Task { @MainActor [weak self] in
                guard let self, let bundleID else { return }
                self.frontmostApp = AppInfo(bundleID: bundleID, displayName: name ?? String(localized: "未知应用"), appPath: path)
                self.onFrontmostAppChanged?(bundleID)
            }
        }
        observerTokens.append(activateToken)
    }

    /// 停止应用监控
    func stopMonitoring() {
        let nc = NSWorkspace.shared.notificationCenter
        for token in observerTokens {
            nc.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    /// 刷新运行应用列表
    func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { app in
                AppInfo(
                    bundleID: app.bundleIdentifier ?? "unknown",
                    displayName: app.localizedName ?? String(localized: "未知应用"),
                    appPath: app.bundleURL?.path
                )
            }
    }

    /// 检查指定应用是否正在运行
    func isAppRunning(bundleID: String) -> Bool {
        runningApps.contains { $0.bundleID == bundleID }
    }

    /// 获取正在运行的应用（按 Bundle ID 查找）
    func runningApp(for bundleID: String) -> AppInfo? {
        runningApps.first { $0.bundleID == bundleID }
    }
}
