import Foundation
import AppKit
import ApplicationServices
import Observation
import Security

/// 辅助功能权限查询与请求（可注入，便于单元测试）
protocol AccessibilityTrustProviding: Sendable {
    /// 辅助功能权限当前是否已授予
    func isTrusted() -> Bool
    /// 请求辅助功能权限（可能弹出系统对话框）；返回请求后的授权状态
    @MainActor func requestTrust() -> Bool
}

/// 真实实现：包装 AXIsProcessTrusted / AXIsProcessTrustedWithOptions
struct AXAccessibilityTrustProvider: AccessibilityTrustProviding {
    /// 弹出系统授权对话框的选项 key。用字符串字面量规避 `kAXTrustedCheckOptionPrompt`
    /// 全局变量在 Swift 6 严格并发下的「非隔离全局状态」报错。
    private static let promptOptionKey = "AXTrustedCheckOptionPrompt"

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    func requestTrust() -> Bool {
        let options = [Self.promptOptionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

/// 代码签名诊断：判断 app 是否为 ad-hoc 签名。
///
/// ad-hoc 签名（`CODE_SIGN_IDENTITY="-"`）的 designated requirement 是 `cdhash H"…"`，
/// 每次改源码重建都会变，导致系统「辅助功能」授权看似保留、实则因 cdhash 不匹配而失效
/// （`AXIsProcessTrusted()` 返回 false，而系统设置里仍显示已授权）。
/// 改用稳定自签名证书后，designated requirement 只依赖 bundle id + 证书，重建不再改变身份。
enum CodeSigningDiagnostics {
    /// 判断指定 app bundle 是否为 ad-hoc 签名；无法读取签名信息时返回 nil。
    static func isAdHocSigned(bundleURL: URL) -> Bool? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }

        guard let flags = dict[kSecCodeInfoFlags as String] as? NSNumber else { return nil }
        // kSecCodeSignatureAdhoc（CSCommon.h = 0x0002）：无签名者（ad-hoc）标志
        return (flags.uint32Value & SecCodeSignatureFlags.adhoc.rawValue) != 0
    }
}

/// 权限管理器：集中管理辅助功能权限状态（供 UI 展示与请求），
/// 消除原先引导页与总览页的重复实现。
@MainActor
@Observable
final class PermissionManager {
    private let trustProvider: any AccessibilityTrustProviding

    /// 辅助功能权限是否已授予
    private(set) var accessibilityGranted: Bool

    /// 观察者 token（生命周期与 App 一致，无需移除）
    private var observers: [NSObjectProtocol] = []

    /// 周期性刷新 Timer（权限状态是「外部变更」，靠定时重查保证及时同步）
    private var refreshTimer: Timer?

    /// 是否已输出过「未授权」诊断日志（避免 3 秒轮询反复刷屏）
    private var didLogDeniedDiagnostic = false

    /// 是否需要重启应用才能让授权生效。
    /// macOS 对「运行中进程」缓存授权状态：在系统设置里授权后，当前进程的
    /// AXIsProcessTrusted() 仍返回 false，必须重启才会重新读取。
    private(set) var needsRestartToApplyAccessibility = false

    /// 是否刚跳转去系统设置（didBecomeActive 时据此判断是否提示重启）
    private var pendingSettingsReturn = false

    init(trustProvider: any AccessibilityTrustProviding = AXAccessibilityTrustProvider()) {
        self.trustProvider = trustProvider
        self.accessibilityGranted = trustProvider.isTrusted()
        observePermissionChanges()
        startPeriodicRefresh()
    }

    /// 启动周期性刷新：每 3 秒重新查询一次 AXIsProcessTrusted()。
    /// 应用切换为 .accessory（菜单栏模式）后，didBecomeActive 可能不再可靠触发，
    /// 这里用轻量定时重查兜底，确保权限状态在用户授权后能及时更新。
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    /// 刷新权限状态（例如用户从系统设置返回后）
    func refresh() {
        let granted = trustProvider.isTrusted()
        if granted != accessibilityGranted {
            accessibilityGranted = granted
            NSLog("[PermissionManager] 辅助功能权限状态变化: %@", granted ? "已授权" : "未授权")
        }
        if granted {
            needsRestartToApplyAccessibility = false
        }

        // 未授权时输出一次可操作的诊断（指出是否 ad-hoc 签名这个常见根因），授权后复位
        if !granted {
            if !didLogDeniedDiagnostic {
                didLogDeniedDiagnostic = true
                logDeniedDiagnostic()
            }
        } else {
            didLogDeniedDiagnostic = false
        }
    }

    /// 请求辅助功能权限（可能弹出系统对话框），返回请求后是否已授予
    @discardableResult
    func requestAccessibility() -> Bool {
        pendingSettingsReturn = true
        let granted = trustProvider.requestTrust()
        accessibilityGranted = granted
        return granted
    }

    /// 打开系统设置 → 隐私与安全性 → 辅助功能
    func openAccessibilitySettings() {
        pendingSettingsReturn = true
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// 重启应用以应用辅助功能授权（运行中进程缓存了旧授权状态，重启后才会重新读取）
    func restartToApplyAccessibility() {
        // LOW-9 修复：用非弃用的 Process.run() 替代 launch()，executableURL 替代 launchPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: - 诊断

    private func logDeniedDiagnostic() {
        switch CodeSigningDiagnostics.isAdHocSigned(bundleURL: Bundle.main.bundleURL) {
        case true:
            NSLog("[PermissionManager] ⚠️ 未授权辅助功能，且当前为 ad-hoc 签名——每次重建 cdhash 都变，系统设置里的授权会失效。请改用稳定证书签名后重新授权。")
        case false:
            NSLog("[PermissionManager] 未授权辅助功能（已用稳定证书签名）。若系统设置已开启授权仍无效，请移除并重新添加 AutoToggle 后重启应用。")
        case nil:
            NSLog("[PermissionManager] 未授权辅助功能，且无法读取当前签名信息。")
        }
    }

    // MARK: - 外部变更监听

    /// 监听外部授权状态变化，自动重新查询 AXIsProcessTrusted()。
    /// 授权状态是「外部变更」，macOS 不会主动推送，只能靠重新查询获取信号。
    private func observePermissionChanges() {
        // 用户从「系统设置」返回本应用时会激活应用 → 立即重新查询
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleAppBecameActive() }
        })

        // 系统 TCC 辅助功能授权变化时广播的分布式通知（尽力而为，未公开 API，不触发也不影响）
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
    }

    /// 应用重新激活（如用户从系统设置返回）时：刷新状态，并判断是否需要提示重启。
    /// internal 以便单元测试直接调用（didBecomeActive 观察者用 Task 异步包装，测试不便等待）。
    func handleAppBecameActive() {
        let returningFromSettings = pendingSettingsReturn
        pendingSettingsReturn = false
        refresh()
        // 从系统设置返回后仍显示「未授权」，很可能是 macOS 对运行中进程缓存了旧授权状态，
        // 需要重启才能生效——给出提示（用户也可能未真正授权，措辞用「若」以免误导）。
        if returningFromSettings && !accessibilityGranted {
            needsRestartToApplyAccessibility = true
            NSLog("[PermissionManager] 从系统设置返回后仍未授权，提示重启应用以应用授权")
        }
    }
}
