import Foundation
import AppKit
import ApplicationServices
import Observation

/// 辅助功能权限查询与请求（可注入，便于单元测试）
protocol AccessibilityTrustProviding: Sendable {
    /// 辅助功能权限当前是否已授予
    func isTrusted() -> Bool
    /// 请求辅助功能权限（可能弹出系统对话框）；返回请求后的授权状态
    @MainActor func requestTrust() -> Bool
}

/// 真实实现：包装 AXIsProcessTrusted / AXIsProcessTrustedWithOptions
struct AXAccessibilityTrustProvider: AccessibilityTrustProviding {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    func requestTrust() -> Bool {
        // 使用字面量 key，规避 kAXTrustedCheckOptionPrompt 全局变量在 Swift 6 下的并发安全报错
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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

    init(trustProvider: any AccessibilityTrustProviding = AXAccessibilityTrustProvider()) {
        self.trustProvider = trustProvider
        self.accessibilityGranted = trustProvider.isTrusted()
        observePermissionChanges()
    }

    /// 刷新权限状态（例如用户从系统设置返回后）
    func refresh() {
        let granted = trustProvider.isTrusted()
        if granted != accessibilityGranted {
            accessibilityGranted = granted
        }
    }

    /// 请求辅助功能权限（可能弹出系统对话框），返回请求后是否已授予
    @discardableResult
    func requestAccessibility() -> Bool {
        let granted = trustProvider.requestTrust()
        accessibilityGranted = granted
        return granted
    }

    /// 打开系统设置 → 隐私与安全性 → 辅助功能
    func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// 监听外部授权状态变化，自动重新查询 AXIsProcessTrusted()。
    /// 授权状态是「外部变更」，macOS 不会主动推送，只能靠重新查询获取信号。
    private func observePermissionChanges() {
        // 用户从「系统设置」返回本应用时会激活应用 → 立即重新查询
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
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
}
