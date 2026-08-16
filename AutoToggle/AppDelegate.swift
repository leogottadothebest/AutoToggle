import AppKit
import SwiftUI

/// 应用代理：使用原生 NSWindow + NSHostingView 管理主窗口（启动时自动弹出并置前），菜单栏作为辅助入口
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    /// 由 AutoToggleApp 注入的依赖集合
    var dependencies: AppDependencies?

    /// 主窗口引用
    private var mainWindow: NSWindow?

    /// 菜单栏图标 + 面板控制器
    private var menuBarController: MenuBarController?

    // MARK: - 应用生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 标准应用（Dock 图标可见），启动即弹出主窗口
        NSApp.setActivationPolicy(.regular)

        guard let deps = dependencies else { return }

        deps.appearanceManager.activate()

        // 启动各引擎：原先在菜单栏面板首次打开时才启动，
        // 导致未打开面板时定时/闲置规则不生效
        deps.appMonitorManager.startMonitoring()
        deps.idleDetectorManager.startMonitoring()
        deps.scheduleManager.startScheduling()

        // 全局快捷键：⌥⌘P 切换暂停/恢复（需辅助功能权限）
        deps.globalHotkeyManager.start { [weak deps] in
            deps?.menuBarManager.togglePause()
        }

        createAndShowMainWindow()

        // 菜单栏图标 + 非激活面板（不抢占其它应用的键盘焦点）
        menuBarController = MenuBarController(dependencies: deps) { [weak self] in
            self?.showMainWindow()
        }
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
            .environment(deps.updateManager)
            .environment(deps.diagnosticsManager)

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
        window.delegate = self

        mainWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// 显示已存在的主窗口（置前并获得焦点）
    func showMainWindow() {
        // 先收起菜单栏面板，避免其盖在主窗口之上
        menuBarController?.closePanel()

        // 若之前关闭窗口已转入菜单栏模式（Dock 隐藏），恢复 Dock 图标
        NSApp.setActivationPolicy(.regular)

        guard let window = mainWindow else {
            createAndShowMainWindow()
            return
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        // activateIgnoringOtherApps 虽已废弃，但仍是唯一能可靠「抢焦点置前」的方式（见 JavaFX/OpenJDK 的结论）
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    // MARK: - NSWindowDelegate

    /// 点击红色关闭键后：主窗口关闭，app 转为纯菜单栏模式（从 Dock 消失），
    /// 引擎继续在后台运行；点击菜单栏「主界面」可重新显示并恢复 Dock 图标。
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
