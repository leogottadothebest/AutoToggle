import AppKit
import SwiftUI

/// 应用代理：使用原生 NSWindow + NSHostingView 管理主窗口
/// 主界面是 app 的核心，菜单栏仅作为辅助入口
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 由 AutoToggleApp 注入的依赖集合
    var dependencies: AppDependencies?

    /// 主窗口引用
    private var mainWindow: NSWindow?

    // MARK: - 应用生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 标准应用（Dock 图标可见）
        NSApp.setActivationPolicy(.regular)

        guard let deps = dependencies else { return }

        deps.appearanceManager.activate()

        // 启动各引擎：原先在菜单栏面板首次打开时才启动，
        // 导致未打开面板时定时/闲置规则不生效
        deps.appMonitorManager.startMonitoring()
        deps.idleDetectorManager.startMonitoring()
        deps.scheduleManager.startScheduling()

        createAndShowMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    // MARK: - 原生主窗口创建

    private func createAndShowMainWindow() {
        guard let deps = dependencies else { return }

        let contentView = MainWindowView()
            .modelContainer(deps.modelContainer)
            .environment(deps.ruleManager)
            .environment(deps.appMonitorManager)
            .environment(deps.idleDetectorManager)
            .environment(deps.appActionManager)
            .environment(deps.scheduleManager)
            .environment(deps.logManager)
            .environment(deps.profileManager)
            .environment(deps.appearanceManager)
            .environment(deps.permissionManager)
            .environment(deps.sleepPreventionManager)

        let hostingView = NSHostingView(rootView: contentView)
        // NSHostingView 默认高度很矮，给它合理的初始大小
        hostingView.frame.size = NSSize(width: 720, height: 520)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "AutoToggle"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("MainWindow")
        // 关闭窗口时仅移除窗口，app 继续在菜单栏运行
        window.isReleasedWhenClosed = false

        mainWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显示已存在的主窗口
    func showMainWindow() {
        guard let window = mainWindow else {
            createAndShowMainWindow()
            return
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
