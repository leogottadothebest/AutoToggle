import SwiftUI

/// AutoToggle 应用入口
/// 主窗口由 AppDelegate 以原生 NSWindow + NSHostingView 创建并管理；
/// 菜单栏图标由 MenuBarController 以 NSStatusItem + 非激活 NSPanel 管理。
/// 两者都基于 AppKit，因此这里无需声明任何 SwiftUI Scene。
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
        // 无 SwiftUI 场景：主窗口与菜单栏图标均由 AppKit 侧创建。
    }
}
