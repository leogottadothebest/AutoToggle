import AppKit
import SwiftUI

/// 菜单栏图标 + 下拉面板控制器。
///
/// 用 `NSStatusItem` + `NSPopover(.transient)` 实现菜单栏下拉面板：
/// - `NSPopover` 的 `behavior = .transient` 会在点击面板外时自动关闭，且不会激活整个 app，
///   因此不会像 SwiftUI `MenuBarExtra(.window)` 那样抢占其它应用的键盘焦点；
/// - `NSPopover` 的内容本身就是为交互设计的，SwiftUI 按钮可正常点击（规避了非激活 `NSPanel`
///   里按钮收不到点击的问题）。
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let dependencies: AppDependencies
    private let onOpenMainWindow: () -> Void

    init(dependencies: AppDependencies, onOpenMainWindow: @escaping () -> Void) {
        self.dependencies = dependencies
        self.onOpenMainWindow = onOpenMainWindow
        super.init()
        setupStatusItem()
        setupPopover()
    }

    // MARK: - 状态栏图标

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover)
        }
        statusItem = item
    }

    // MARK: - 面板内容

    private var contentView: some View {
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
            .frame(width: 300)
            // 不叠加不透明背景：让 NSPopover 自身的材质（含顶部箭头）完整透出，
            // 避免箭头颜色与面板主体色不一致。外观由 NSApp.appearance + popover.appearance 驱动。
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.appearance = popoverAppearance
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.delegate = self
    }

    /// 依据当前生效外观返回 NSPopover 外观（箭头/边框跟随同一套浅深色方案）
    private var popoverAppearance: NSAppearance? {
        dependencies.appearanceManager.effectiveColorScheme == .dark
            ? NSAppearance(named: .darkAqua)
            : NSAppearance(named: .aqua)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // 每次展开前刷新外观，覆盖用户在主窗口里刚切换了浅/深色的场景
            popover.appearance = popoverAppearance
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// 关闭面板（「主界面」按钮触发时先收起面板，再弹出主窗口）
    func closePanel() {
        popover.performClose(nil)
    }
}
