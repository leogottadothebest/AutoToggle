import SwiftUI

/// AutoToggle 应用入口
/// 主界面由 AppDelegate 以原生 NSWindow + NSHostingView 创建并管理
/// 菜单栏图标由 MenuBarExtra 场景提供（辅助入口）
@main
struct AutoToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// 集中管理所有依赖（管理器与容器）
    private let dependencies: AppDependencies

    init() {
        let dependencies = AppDependencies()
        self.dependencies = dependencies
        appDelegate.dependencies = dependencies
    }

    var body: some Scene {
        // 菜单栏图标 + 下拉面板（辅助入口）
        MenuBarExtra {
            MenuBarContentView()
                .modelContainer(dependencies.modelContainer)
                .environment(dependencies.menuBarManager)
                .environment(dependencies.ruleManager)
                .environment(dependencies.appMonitorManager)
                .environment(dependencies.idleDetectorManager)
                .environment(dependencies.appActionManager)
                .environment(dependencies.scheduleManager)
                .environment(dependencies.logManager)
                .environment(dependencies.profileManager)
                .environment(dependencies.appearanceManager)
                .environment(dependencies.permissionManager)
                .environment(dependencies.sleepPreventionManager)
                .preferredColorScheme(dependencies.appearanceManager.effectiveColorScheme)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)

        // 主窗口已由 AppDelegate 以原生 NSWindow 创建 — 无需 WindowGroup
    }
}
