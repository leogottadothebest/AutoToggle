import SwiftUI

/// AutoToggle 应用入口
/// 主窗口由 AppDelegate 以原生 NSWindow + NSHostingView 创建并管理；
/// 菜单栏图标由 SwiftUI `MenuBarExtra`（`.menu` 样式，即传统 NSMenu）承载。
@main
struct AutoToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// 集中管理所有依赖（管理器与容器）
    private let dependencies: AppDependencies

    init() {
        // 在任何本地化查找之前应用所选语言（需早于 AppDependencies 创建，因其日志/断言已含本地化文案）
        LanguageManager.applyStoredLanguage()

        let dependencies = AppDependencies()
        self.dependencies = dependencies
        appDelegate.dependencies = dependencies
    }

    var body: some Scene {
        // 传统菜单样式的菜单栏入口：展开的是真 NSMenu，点击别处被系统吞掉、不穿透到墙纸
        // （自建窗口面板做不到这点——见 StatusMenuView 的说明）
        MenuBarExtra {
            StatusMenuView { appDelegate.showMainWindow() }
                .environment(dependencies.menuBarManager)
                .environment(dependencies.sleepPreventionManager)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)
    }

    /// 菜单栏图标。
    /// 必须显式设定尺寸：资源本身是 30×30，直接交给 SwiftUI 会按原始尺寸渲染，状态项过宽（实测 48pt）。
    /// 30pt 即资源原始尺寸（用户选定）。
    private static var menuBarIcon: NSImage {
        let image = NSImage(named: "MenuBarIcon") ?? NSImage()
        image.size = NSSize(width: 30, height: 30)
        image.isTemplate = true
        image.accessibilityDescription = "AutoToggle"
        return image
    }
}
