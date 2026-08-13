import Foundation
import AppKit
import ApplicationServices

/// 当前拥有键盘焦点的应用 Bundle ID 提供者
/// 用于判断「哪个应用正在被用户使用」，提升应用闲置判定精度。
protocol FocusedAppProviding: Sendable {
    /// 当前焦点应用 Bundle ID；无法确定时返回 nil
    func focusedAppBundleID() -> String?
}

/// 无需权限：使用 NSWorkspace 前台应用
struct WorkspaceFocusedAppProvider: FocusedAppProviding {
    func focusedAppBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

/// 需要辅助功能权限：读取系统级 AX 焦点应用（键盘焦点，比「前台」更精确）。
/// 未授权时 AXUIElement 读取会失败，返回 nil，由上层回退到 NSWorkspace。
struct AccessibilityFocusedAppProvider: FocusedAppProviding {
    func focusedAppBundleID() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedAppValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppValue
        ) == .success, let focusedAppValue else { return nil }

        // 校验返回值确为 AXUIElement，避免把异常类型强转后传给 C API
        guard CFGetTypeID(focusedAppValue) == AXUIElementGetTypeID() else { return nil }

        // kAXFocusedApplicationAttribute 返回 AXUIElement；用其 PID 反查应用 Bundle ID
        var pid: pid_t = 0
        guard AXUIElementGetPid(focusedAppValue as! AXUIElement, &pid) == .success else { return nil }

        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }
}

/// 权限感知实现：已授权时优先用 AX 焦点，读取失败或未授权时回退到 NSWorkspace。
struct PermissionAwareFocusedAppProvider: FocusedAppProviding {
    private let workspace: WorkspaceFocusedAppProvider
    private let accessibility: AccessibilityFocusedAppProvider
    private let trustProvider: any AccessibilityTrustProviding

    init(
        workspace: WorkspaceFocusedAppProvider = WorkspaceFocusedAppProvider(),
        accessibility: AccessibilityFocusedAppProvider = AccessibilityFocusedAppProvider(),
        trustProvider: any AccessibilityTrustProviding = AXAccessibilityTrustProvider()
    ) {
        self.workspace = workspace
        self.accessibility = accessibility
        self.trustProvider = trustProvider
    }

    func focusedAppBundleID() -> String? {
        if trustProvider.isTrusted() {
            return accessibility.focusedAppBundleID() ?? workspace.focusedAppBundleID()
        }
        return workspace.focusedAppBundleID()
    }
}
