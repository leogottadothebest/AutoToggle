import AppKit
import SwiftUI

/// 菜单栏图标 + 下拉面板控制器。
///
/// 面板内容只有一份（`panelContentView`，全部管理器依赖的注入点），展示方式按系统能力选后端：
/// - **macOS 27+**：系统原生 expanded interface。点击状态项由系统通过 `expandedInterfaceDelegate`
///   回调驱动，不挂 `button.target/action`，面板因此能参与系统的键盘导航（Esc 关闭由系统负责）；
/// - **macOS 14–26**：`NSPopover(.transient)`，点击面板外自动关闭。
///
/// 两条路径都不激活 app，不会抢占其它应用的键盘焦点（这正是当初不用 SwiftUI
/// `MenuBarExtra(.window)` 的原因）。
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let dependencies: AppDependencies
    private let onOpenMainWindow: () -> Void

    /// 面板内容视图控制器：两个后端共用同一实例（互斥，同时只有一个会展示）。
    private lazy var hostingController = NSHostingController(rootView: AnyView(panelContentView))

    /// 展示后端。`init` 里立即构建（不能用 lazy）——macOS 27+ 必须赶在用户第一次点击状态项
    /// 之前就把 `expandedInterfaceDelegate` 装好，惰性构建会拖到 `closePanel()` 才发生，
    /// 导致首次点击状态项毫无反应。
    private var backend: MenuBarPanelBackend?

    init(dependencies: AppDependencies, onOpenMainWindow: @escaping () -> Void) {
        self.dependencies = dependencies
        self.onOpenMainWindow = onOpenMainWindow
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        setupStatusItem()
        backend = makeBackend()
    }

    // MARK: - 展示后端

    private func makeBackend() -> MenuBarPanelBackend {
        if #available(macOS 27.0, *) {
            let expandedPanel = ExpandedPanelBackend(
                statusItem: statusItem,
                contentViewController: hostingController,
                appearanceManager: dependencies.appearanceManager
            )
            // macOS 27+：点击由系统通过 expandedInterfaceDelegate 派发，不挂 button.target/action
            statusItem.expandedInterfaceDelegate = expandedPanel
            return expandedPanel
        }

        let popoverBackend = PopoverPanelBackend(
            contentViewController: hostingController,
            anchorView: statusItem.button,
            appearanceManager: dependencies.appearanceManager
        )
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        return popoverBackend
    }

    // MARK: - 状态栏图标

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(named: "MenuBarIcon")
        button.image?.isTemplate = true
        button.setAccessibilityLabel("AutoToggle")
        button.setAccessibilityTitle("AutoToggle 菜单栏")
        // 点击行为按系统能力安装：macOS 27+ 交给 expandedInterfaceDelegate，更早的系统用 target/action
    }

    // MARK: - 面板内容

    /// 面板内容视图（两个后端共用的唯一注入点）
    private var panelContentView: some View {
        MenuBarContentView(onOpenMainWindow: onOpenMainWindow)
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
            .environment(dependencies.updateManager)
    }

    // MARK: - 交互

    /// 旧系统（macOS 14–26）的状态项点击入口；macOS 27+ 由系统 expanded interface 派发，不走这里。
    @objc private func togglePopover() {
        guard let backend else { return }
        if backend.isShown {
            backend.hide(animated: true)
        } else {
            backend.show(animated: true)
        }
    }

    /// 收起面板（「主界面」按钮触发时先收起面板，再弹出主窗口）
    func closePanel() {
        backend?.hide(animated: true)
    }
}
