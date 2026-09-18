import AppKit

/// 菜单栏下拉面板的展示后端。
///
/// macOS 27 起系统提供了原生 expanded interface（`ExpandedPanelBackend`），
/// 更早的系统回退到 `NSPopover`（`PopoverPanelBackend`）。两者共享同一份面板内容视图。
@MainActor
protocol MenuBarPanelBackend: AnyObject {
    /// 面板当前是否正在展示。
    var isShown: Bool { get }

    /// 展示面板。
    func show(animated: Bool)

    /// 收起面板。幂等：重复调用或会话已结束时是空操作。
    func hide(animated: Bool)

    /// 应用当前浅/深色外观。用户在主窗口切换外观后，下次展开前面板需要跟上。
    func refreshAppearance()
}

extension AppearanceManager {
    /// 菜单栏面板专用的 `NSAppearance`：跟随当前生效的浅/深色方案。
    /// 面板不走 SwiftUI 背景，需要显式给窗口/popover 设外观，箭头与边框才会同色。
    var panelAppearance: NSAppearance? {
        effectiveColorScheme == .dark
            ? NSAppearance(named: .darkAqua)
            : NSAppearance(named: .aqua)
    }
}

/// macOS 14–26 的回退后端：`NSPopover(.transient)`。
///
/// `.transient` 在点击面板外时自动关闭，且不激活 app，因此不会像 SwiftUI
/// `MenuBarExtra(.window)` 那样抢占其它应用的键盘焦点。
@MainActor
final class PopoverPanelBackend: MenuBarPanelBackend {
    private let popover = NSPopover()
    private let appearanceManager: AppearanceManager
    private weak var anchorView: NSView?

    init(
        contentViewController: NSViewController,
        anchorView: NSView?,
        appearanceManager: AppearanceManager
    ) {
        self.anchorView = anchorView
        self.appearanceManager = appearanceManager

        popover.behavior = .transient
        popover.animates = false
        popover.appearance = appearanceManager.panelAppearance
        popover.contentViewController = contentViewController
    }

    var isShown: Bool { popover.isShown }

    func show(animated: Bool) {
        guard let anchorView, !popover.isShown else { return }
        refreshAppearance()
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    func hide(animated: Bool) {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func refreshAppearance() {
        popover.appearance = appearanceManager.panelAppearance
    }
}
