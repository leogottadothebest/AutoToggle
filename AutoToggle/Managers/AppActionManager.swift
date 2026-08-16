import AppKit
import Foundation

/// 退出策略
enum QuitStrategy: String, CaseIterable {
    /// 仅 AppleScript 优雅退出，失败则记录警告（不执行后续降级）
    case normal
    /// AppleScript → terminate → forceTerminate 三级尝试
    case force

    var localizedName: String {
        switch self {
        case .normal: return String(localized: "quitStrategy.normal")
        case .force: return String(localized: "quitStrategy.force")
        }
    }
}

/// 应用操作管理器
/// 负责应用的启动、退出（支持普通/强制两种策略）、隐藏和激活操作
@MainActor
@Observable
final class AppActionManager {
    /// 日志管理器引用（可选注入）
    private weak var logManager: LogManager?

    /// 注入日志管理器
    func configure(logManager: LogManager) {
        self.logManager = logManager
    }

    // MARK: - 启动应用

    /// 启动应用（通过 Bundle ID）
    /// - Parameter bundleID: 目标应用的 Bundle Identifier
    func launchApp(bundleID: String) {
        guard BundleHelper.isValidBundleID(bundleID) else {
            logManager?.addSystem(message: String(localized: "log.rejectLaunch \(bundleID)"), level: .error)
            return
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            print("[AppActionManager] 找不到应用: \(bundleID)")
            return
        }

        // 检查应用是否已在运行
        if isAppRunning(bundleID: bundleID) {
            activateApp(bundleID: bundleID)
            return
        }

        let displayName = BundleHelper.displayName(for: appURL.path) ?? bundleID
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
            if let error {
                print("[AppActionManager] 启动应用失败 \(bundleID): \(error.localizedDescription)")
                Task { @MainActor in
                    self?.logManager?.addSystem(
                        message: String(localized: "log.launchFailed \(displayName) \(error.localizedDescription)"),
                        level: .error
                    )
                }
            }
            // 成功启动不在此记活动日志：由触发方（定时启动）或菜单栏手动操作单独记录，避免重复
        }
    }

    // MARK: - 退出应用

    /// 退出应用
    /// - Parameters:
    ///   - bundleID: 目标应用的 Bundle Identifier
    ///   - strategy: 退出策略（普通 = 仅 AppleScript，强制 = 三级降级）
    func terminateApp(bundleID: String, strategy: QuitStrategy = .normal) {
        guard BundleHelper.isValidBundleID(bundleID) else {
            logManager?.addSystem(message: String(localized: "log.rejectQuit \(bundleID)"), level: .error)
            return
        }
        guard let runningApp = findRunningApp(bundleID: bundleID) else {
            return
        }

        let appName = runningApp.localizedName ?? bundleID

        // 第一级：AppleScript 优雅退出
        let scriptSuccess = attemptGracefulQuitViaAppleScript(bundleID: bundleID)

        if scriptSuccess {
            // 不在活动日志重复记录：触发方（闲置退出/定时退出）已记录语义化条目，手动退出由菜单栏记录
            return
        }

        // 普通退出模式：AppleScript 失败则记录警告并停止
        guard strategy == .force else {
            logManager?.addSystem(
                message: String(localized: "log.normalQuitFailed \(appName)"),
                level: .warning
            )
            return
        }

        // 强制退出模式：继续第二级和第三级降级。
        // L-4：AppleScript 优雅退出可能已让应用真正退出、但脚本仍返回错误，此时 runningApp
        // 是陈旧快照（其 PID 可能已被系统复用给其它进程）。先按 bundleID 重新解析并校验
        // PID 未变，避免 terminate() 误杀同用户的无关进程（CWE-362）。
        guard let current = findRunningApp(bundleID: bundleID),
              current.processIdentifier == runningApp.processIdentifier else {
            return
        }
        _ = current.terminate()

        // 给 terminate 3 秒时间生效
        Task {
            try? await Task.sleep(for: .seconds(3))
            // LOW-4 修复：重新按 bundleID 查找当前实例，避免陈旧 PID 被复用导致误杀（CWE-362）
            guard let current = findRunningApp(bundleID: bundleID), !current.isTerminated else { return }
            attemptForceTerminate(current)
            logManager?.addSystem(message: String(localized: "log.forceQuit \(appName)"), level: .warning)
        }
    }

    /// 隐藏应用
    /// - Parameter bundleID: 目标应用的 Bundle Identifier
    func hideApp(bundleID: String) {
        guard BundleHelper.isValidBundleID(bundleID) else {
            logManager?.addSystem(message: String(localized: "log.rejectHide \(bundleID)"), level: .error)
            return
        }
        guard findRunningApp(bundleID: bundleID) != nil else { return }

        let script = """
        tell application id "\(bundleID)"
            set visible of every window to false
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                print("[AppActionManager] 隐藏应用失败 \(bundleID): \(error)")
            }
        }
    }

    /// 激活应用（带到前台）
    /// - Parameter bundleID: 目标应用的 Bundle Identifier
    func activateApp(bundleID: String) {
        guard BundleHelper.isValidBundleID(bundleID) else {
            logManager?.addSystem(message: String(localized: "log.rejectActivate \(bundleID)"), level: .error)
            return
        }
        guard let runningApp = findRunningApp(bundleID: bundleID) else {
            launchApp(bundleID: bundleID)
            return
        }
        runningApp.activate(options: .activateAllWindows)
    }

    // MARK: - 查询

    /// 检查应用是否在运行
    func isAppRunning(bundleID: String) -> Bool {
        findRunningApp(bundleID: bundleID) != nil
    }

    // MARK: - 内部方法

    /// 查找运行中的应用实例
    private func findRunningApp(bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
    }

    /// 第一级：AppleScript 优雅退出（同步执行，quit 命令通常瞬间完成）
    private func attemptGracefulQuitViaAppleScript(bundleID: String) -> Bool {
        // 纵深防御：即使上层漏过，这里也拒绝任何可能破坏 AppleScript 字符串的 Bundle ID
        guard BundleHelper.isValidBundleID(bundleID) else { return false }

        let script = """
        tell application id "\(bundleID)"
            quit
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return false
        }

        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)

        if let error {
            print("[AppActionManager] AppleScript 退出失败 \(bundleID): \(error)")
            return false
        }

        return true
    }

    /// 第三级：强制终止（系统安全 API，框架内部校验 PID 归属，替代裸 kill()）
    private func attemptForceTerminate(_ runningApp: NSRunningApplication) {
        print("[AppActionManager] 强制终止: \(runningApp.localizedName ?? "未知应用") (PID \(runningApp.processIdentifier))")
        _ = runningApp.forceTerminate()
    }
}
