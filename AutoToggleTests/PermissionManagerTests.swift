import Testing
import Foundation
@testable import AutoToggle

/// PermissionManager 的权限状态逻辑测试（通过假信任提供者注入，无需真实权限交互）
@Suite
struct PermissionManagerTests {
    @Test
    @MainActor
    func 初始化读取授权状态() {
        let granted = PermissionManager(trustProvider: FakeTrustProvider(trusted: true))
        #expect(granted.accessibilityGranted)

        let denied = PermissionManager(trustProvider: FakeTrustProvider(trusted: false))
        #expect(!denied.accessibilityGranted)
    }

    @Test
    @MainActor
    func refresh重新读取授权状态() {
        let provider = FakeTrustProvider(trusted: false)
        let manager = PermissionManager(trustProvider: provider)
        #expect(!manager.accessibilityGranted)

        // 模拟用户在系统设置中授予后，refresh 应反映新状态
        provider.trusted = true
        manager.refresh()
        #expect(manager.accessibilityGranted)
    }

    @Test
    @MainActor
    func requestAccessibility请求并更新状态() {
        let provider = FakeTrustProvider(trusted: false, requestResult: true)
        let manager = PermissionManager(trustProvider: provider)

        let granted = manager.requestAccessibility()
        #expect(granted)
        #expect(manager.accessibilityGranted)
    }

    @Test
    @MainActor
    func 请求被拒绝时状态保持未授权() {
        let provider = FakeTrustProvider(trusted: false, requestResult: false)
        let manager = PermissionManager(trustProvider: provider)

        let granted = manager.requestAccessibility()
        #expect(!granted)
        #expect(!manager.accessibilityGranted)
    }

    @Test
    @MainActor
    func 从系统设置返回后仍授权提示重启() {
        // macOS 对运行中进程缓存授权状态：授权后 AXIsProcessTrusted() 仍返回 false，需重启。
        let provider = FakeTrustProvider(trusted: false)
        let manager = PermissionManager(trustProvider: provider)
        #expect(!manager.needsRestartToApplyAccessibility)

        manager.openAccessibilitySettings()
        manager.handleAppBecameActive() // 模拟从系统设置返回

        #expect(manager.needsRestartToApplyAccessibility)
    }

    @Test
    @MainActor
    func 返回时已授权则不提示重启() {
        let provider = FakeTrustProvider(trusted: false)
        let manager = PermissionManager(trustProvider: provider)

        // 用户在系统设置中授权后（provider 变为 trusted），返回应用
        provider.trusted = true
        manager.openAccessibilitySettings()
        manager.handleAppBecameActive()

        #expect(manager.accessibilityGranted)
        #expect(!manager.needsRestartToApplyAccessibility)
    }

    @Test
    @MainActor
    func 未去系统设置直接激活不提示重启() {
        let provider = FakeTrustProvider(trusted: false)
        let manager = PermissionManager(trustProvider: provider)

        manager.handleAppBecameActive() // 未先 openAccessibilitySettings/requestAccessibility

        #expect(!manager.needsRestartToApplyAccessibility)
    }
}

/// 测试用假信任提供者（类 + 可变状态，仅用于单线程测试环境）
final class FakeTrustProvider: AccessibilityTrustProviding, @unchecked Sendable {
    var trusted: Bool
    var requestResult: Bool

    init(trusted: Bool, requestResult: Bool = false) {
        self.trusted = trusted
        self.requestResult = requestResult
    }

    func isTrusted() -> Bool { trusted }

    @MainActor
    func requestTrust() -> Bool { requestResult }
}
