import SwiftUI

/// 菜单栏下拉菜单（传统菜单样式）。
///
/// 用 `MenuBarExtra` + `.menuBarExtraStyle(.menu)` 承载，展开的是**真正的 NSMenu**。
/// 关键差别：菜单展开时系统会进入菜单跟踪，跟踪期间那次「点别处」的点击被系统**吞掉**，
/// 不会穿透到墙纸触发系统的「点击墙纸以显示桌面」；Esc、键盘导航、选中高亮与展开动画
/// 也都由系统负责。这是自建窗口/面板拿不到的系统行为。
///
/// 代价：菜单只能承载 `Text` / `Button` / `Toggle` / `Divider` 这类条目。
/// 规则编辑、日志、设置等完整管理都在主窗口里，菜单只放高频快捷操作。
struct StatusMenuView: View {
    /// 打开主窗口的回调（由 App 侧注入，避免依赖 `NSApp.delegate`）
    let onOpenMainWindow: () -> Void

    @Environment(MenuBarManager.self) private var menuBarManager
    @Environment(SleepPreventionManager.self) private var sleepPreventionManager

    var body: some View {
        Button("主界面", action: onOpenMainWindow)

        Divider()

        // 菜单每次展开都重新构建，所以标签直接反映当前状态，无需额外同步
        Button(menuBarManager.isPaused ? "恢复规则执行" : "暂停所有规则") {
            menuBarManager.togglePause()
        }

        Button(sleepPreventionManager.isPreventingSystemSleep ? "关闭防系统休眠" : "开启防系统休眠") {
            sleepPreventionManager.toggleSystemSleep()
        }

        Divider()

        Button("退出 AutoToggle") {
            menuBarManager.quitApp()
        }
    }
}
