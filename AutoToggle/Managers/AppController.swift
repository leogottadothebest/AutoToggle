import AppKit
import Foundation

/// 运行中的应用快照抽象。
/// 抽象 NSRunningApplication 的关键接口，便于单元测试注入 fake 记录 terminate/forceTerminate 调用。
@MainActor
protocol RunningAppDescriptor {
    var processIdentifier: pid_t { get }
    var localizedName: String? { get }
    var isTerminated: Bool { get }
    @discardableResult func terminate() -> Bool
    @discardableResult func forceTerminate() -> Bool
    @discardableResult func activate(options: NSApplication.ActivationOptions) -> Bool
}

extension NSRunningApplication: RunningAppDescriptor {}

/// 应用控制抽象。
/// 把 NSWorkspace / NSAppleScript 等系统依赖封装成协议，让 AppActionManager 的
/// 三级退出回退与 PID 复用护栏可被单元测试覆盖（fake 注入）。
@MainActor
protocol AppControlling {
    /// 按 bundle ID 查找运行中的应用
    func runningApp(bundleID: String) -> (any RunningAppDescriptor)?
    /// 按 bundle ID 解析应用 URL
    func urlForApplication(bundleID: String) -> URL?
    /// 打开应用
    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completion: @escaping @Sendable (NSRunningApplication?, Error?) -> Void
    )
    /// 执行 AppleScript，返回是否成功与失败详情
    func executeAppleScript(_ source: String) -> (success: Bool, error: String?)
}

/// 真实系统实现（生产环境默认）
@MainActor
struct NSWorkspaceAppController: AppControlling {
    func runningApp(bundleID: String) -> (any RunningAppDescriptor)? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
    }

    func urlForApplication(bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completion: @escaping @Sendable (NSRunningApplication?, Error?) -> Void
    ) {
        NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: completion)
    }

    func executeAppleScript(_ source: String) -> (success: Bool, error: String?) {
        guard let script = NSAppleScript(source: source) else {
            return (false, "无法创建 NSAppleScript")
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return (false, "\(errorInfo)")
        }
        return (true, nil)
    }
}
