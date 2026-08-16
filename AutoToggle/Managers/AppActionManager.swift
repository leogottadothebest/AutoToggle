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

    /// 系统控制抽象（默认真实实现，测试注入 fake）
    private var controller: any AppControlling = NSWorkspaceAppController()

    /// 注入日志管理器
    func configure(logManager: LogManager) {
        self.logManager = logManager
    }

    /// 注入应用控制实现（测试用）
    func configure(controller: any AppControlling) {
        self.controller = controller
    }

    // MARK: - 启动应用

    /// 启动应用（通过 Bundle ID）
    /// - Parameter bundleID: 目标应用的 Bundle Identifier
    func launchApp(bundleID: String) {
        guard BundleHelper.isValidBundleID(bundleID) else {
            logManager?.addSystem(message: String(localized: "log.rejectLaunch \(bundleID)"), level: .error)
            return
        }
        guard let appURL = controller.urlForApplication(bundleID: bundleID) else {
            Log.appAction.warning("找不到应用: \(bundleID, privacy: .public)")
            logManager?.addSystem(message: String(localized: "log.launchNotFound \(bundleID)"), level: .error)
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

        controller.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error {
                let detail = error.localizedDescription
                Log.appAction.error("启动应用失败 \(bundleID, privacy: .public): \(detail, privacy: .public)")
                // 闭包为 @Sendable，不能在外部作用域捕获非 Sendable 的 self；
                // 这里只捕获 Sendable 值，再跳回 MainActor 访问 self。
                Task { @MainActor [weak self] in
                    self?.logManager?.addSystem(
                        message: String(localized: "log.launchFailed \(displayName) \(detail)"),
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
        guard let runningApp = controller.runningApp(bundleID: bundleID) else {
            return
        }

        let appName = runningApp.localizedName ?? bundleID

        // 第一级：AppleScript 优雅退出
        let scriptResult = controller.executeAppleScript(quitScript(bundleID: bundleID))

        if scriptResult.success {
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
        guard let current = controller.runningApp(bundleID: bundleID),
              current.processIdentifier == runningApp.processIdentifier else {
            return
        }
        let terminatedPID = current.processIdentifier
        _ = current.terminate()

        // 给 terminate 3 秒时间生效
        Task {
            try? await Task.sleep(for: .seconds(3))
            // LOW-4 修复：重新按 bundleID 查找并校验 PID 未变，再 forceTerminate，
            // 避免 3 秒窗口内 PID 被复用（如用户重新打开同款应用）导致误杀无关实例（CWE-362）。
            guard let current = controller.runningApp(bundleID: bundleID),
                  current.processIdentifier == terminatedPID,
                  !current.isTerminated else { return }
            current.forceTerminate()
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
        guard controller.runningApp(bundleID: bundleID) != nil else { return }

        let script = """
        tell application id "\(bundleID)"
            set visible of every window to false
        end tell
        """

        let result = controller.executeAppleScript(script)
        if let error = result.error {
            Log.appAction.warning("隐藏应用失败 \(bundleID, privacy: .public): \(error, privacy: .public)")
            logManager?.addSystem(message: String(localized: "log.hideFailed \(bundleID)"), level: .warning)
        }
    }

    /// 激活应用（带到前台）
    /// - Parameter bundleID: 目标应用的 Bundle Identifier
    func activateApp(bundleID: String) {
        guard BundleHelper.isValidBundleID(bundleID) else {
            logManager?.addSystem(message: String(localized: "log.rejectActivate \(bundleID)"), level: .error)
            return
        }
        guard let runningApp = controller.runningApp(bundleID: bundleID) else {
            launchApp(bundleID: bundleID)
            return
        }
        runningApp.activate(options: .activateAllWindows)
    }

    // MARK: - 查询

    /// 检查应用是否在运行
    func isAppRunning(bundleID: String) -> Bool {
        controller.runningApp(bundleID: bundleID) != nil
    }

    // MARK: - 内部方法

    /// 构造 AppleScript 优雅退出脚本（调用前必须已通过 bundleID 校验，防注入）
    private func quitScript(bundleID: String) -> String {
        """
        tell application id "\(bundleID)"
            quit
        end tell
        """
    }
}
