import AppKit

/// 全局快捷键管理器：注册 ⌥⌘P 切换「暂停/恢复」规则执行。
/// 用 NSEvent 全局监视器实现（需辅助功能权限；应用已请求该权限，未授权时快捷键静默失效）。
@MainActor
@Observable
final class GlobalHotkeyManager {
    private var monitor: Any?

    /// 判断是否为「切换暂停」快捷键：⌥⌘P，且非按住重复触发
    nonisolated static func isTogglePauseHotkey(_ event: NSEvent) -> Bool {
        guard !event.isARepeat else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // keyCode 35 = kVK_ANSI_P（P 键）
        return flags.contains([.command, .option]) && event.keyCode == 35
    }

    /// 启动监视；onToggle 在 MainActor 上回调
    func start(onToggle: @escaping @MainActor () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard Self.isTogglePauseHotkey(event) else { return }
            Task { @MainActor in
                onToggle()
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
