import AppKit

/// macOS 27+ 的原生展开面板后端。
///
/// 用系统新增的 expanded interface 机制（`NSStatusItem.expandedInterfaceDelegate`）：
/// 状态项不再挂 target/action，点击由系统识别后回调 `didBegin`，我们再把面板窗口摆到状态项下方；
/// 会话结束时回调 `didEnd`。这样面板能参与系统的键盘导航与菜单跟踪（Esc 由系统负责关闭）。
///
/// 实机验证过的行为（macOS 27.0）：
/// - 不设 `button.target/action` 时点击状态项仍会触发 `didBegin`；
/// - 面板保持非激活（`NSApp.isActive == false`、无 key window），不抢占其它应用的键盘焦点，
///   但面板内的 SwiftUI 控件可以正常点击；
/// - **点击面板外、以及面板打开时再点状态项，系统都不会结束会话**，必须由我们自己检测并
///   调 `session.cancel()`——见 `installDismissMonitors()`。
@available(macOS 27.0, *)
@MainActor
final class ExpandedPanelBackend: NSObject, MenuBarPanelBackend, @preconcurrency NSStatusItemExpandedInterfaceDelegate {
    private let statusItem: NSStatusItem
    private let contentViewController: NSViewController
    private let appearanceManager: AppearanceManager

    private var panel: NSPanel?
    private var dismissMonitors: [Any] = []
    private var isTearingDown = false
    private var hideDelaySelector = #selector(finishHiding)

    /// 本次会话的开始时刻（`NSEvent.timestamp` 同为开机起的秒数，可直接比较）。
    /// 用于忽略「触发本次会话的那次点击」——它落在状态项上、天然在面板之外。
    private var sessionStartTime: TimeInterval = 0

    private(set) var isShown = false

    init(
        statusItem: NSStatusItem,
        contentViewController: NSViewController,
        appearanceManager: AppearanceManager
    ) {
        self.statusItem = statusItem
        self.contentViewController = contentViewController
        self.appearanceManager = appearanceManager
        super.init()
    }

    // MARK: - MenuBarPanelBackend

    func show(animated: Bool) {
        guard !isShown else { return }
        let panel = makePanelIfNeeded()
        refreshAppearance()
        positionPanel(panel)

        isShown = true
        installDismissMonitors()

        // 先在 alpha 0 状态下上屏并跑一次真实布局，再校准高度。
        // 原因：离屏测得的 fittingSize 会低估——SwiftUI 的 ScrollView 在没有窗口时只报最小高度，
        // 面板因此比内容矮一点，ScrollView 就会溢出并冒出滚动条。校准发生在淡入之前，看不见跳变。
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()
        synchronizeHeight(of: panel)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
        }
    }

    /// 把面板高度校准到内容在窗口内的真实需求；顶边保持不动，视觉上只向下延伸
    private func synchronizeHeight(of panel: NSPanel) {
        guard let glass = panel.contentView else { return }
        let needed = contentViewController.view.fittingSize
        guard needed.height > 0, abs(needed.height - glass.frame.height) > 0.01 else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - needed.height
        frame.size.height = needed.height
        panel.setFrame(frame, display: true)
    }

    func hide(animated: Bool) {
        // 重入保护：hide() 里的 cancel() 会同步回调 didEnd → 再进 hide()，
        // 这里挡掉第二次，保证只 teardown 一次。
        guard !isTearingDown else { return }
        isTearingDown = true
        defer { isTearingDown = false }

        // 我们自己主动收起时必须 cancel 让系统同步会话状态；
        // 系统自己结束会话时该属性已被置空（头文件保证），所以不会重复 cancel。
        statusItem.expandedInterfaceSession?.cancel()
        teardown(animated: animated)
    }

    func refreshAppearance() {
        panel?.appearance = appearanceManager.panelAppearance
    }

    // MARK: - NSStatusItemExpandedInterfaceDelegate

    func statusItem(
        _ statusItem: NSStatusItem,
        didBegin session: NSStatusItemExpandedInterfaceSession
    ) {
        // 上一轮若有未执行的收起延时，取消掉避免它把新面板又收起来
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: hideDelaySelector, object: nil)
        // 必须先记录再 show()：否则触发本次会话的那次点击会被关闭检测当成「点击面板外」
        sessionStartTime = ProcessInfo.processInfo.systemUptime
        show(animated: true)
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        hide(animated: animated)
    }

    // MARK: - 面板窗口

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let contentView = contentViewController.view
        var size = contentView.fittingSize
        if size.width <= 0 || size.height <= 0 {
            Log.general.error("展开面板内容视图尺寸无效，回退到默认尺寸")
            size = NSSize(width: 300, height: 240)
        }

        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
        glass.style = .regular
        glass.cornerRadius = 16
        glass.effectIsInteractive = true
        contentView.autoresizingMask = [.width, .height]
        glass.contentView = contentView

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        // 透明底 + 玻璃视图自己画背景，否则矩形窗口底会从圆角外露出来
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = glass

        self.panel = panel
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let button = statusItem.button, let buttonWindow = button.window else {
            Log.general.error("状态项按钮不可用，无法定位展开面板")
            return
        }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? anchor

        panel.setFrame(
            PanelPositioning.frame(anchor: anchor, panelSize: panel.frame.size, visibleFrame: visibleFrame),
            display: true
        )
    }

    private func teardown(animated: Bool) {
        removeDismissMonitors()
        isShown = false

        guard let panel else { return }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: hideDelaySelector, object: nil)

        if animated, panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 0
            }
            // 用 perform 延时而不是 asyncAfter/Timer 闭包：它们捕获 NSPanel 会在 Swift 6 严格并发下报错
            perform(hideDelaySelector, with: nil, afterDelay: 0.14)
        } else {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    @objc private func finishHiding() {
        panel?.orderOut(nil)
        panel?.alphaValue = 1
    }

    // MARK: - 关闭检测

    /// 装鼠标监听，实现「点击面板外收起」。
    ///
    /// 系统不接管这两种关闭：点面板外、以及面板打开时再点状态项，都需要我们调 `session.cancel()`。
    /// 同一个判断顺带恢复了状态项开关式切换——再点状态项时鼠标落在面板外，走进同一分支。
    ///
    /// 全局监听需要辅助功能权限。本 app 本来就在引导用户授权，且 `GlobalHotkeyManager` 已依赖全局监听；
    /// **未授权时全局监听收不到事件，面板就只能靠 Esc 关闭**——这是可接受的降级。
    private func installDismissMonitors() {
        guard dismissMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]

        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.dismissIfMouseDownIsOutsidePanel(event)
            return event
        }) {
            dismissMonitors.append(local)
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.dismissIfMouseDownIsOutsidePanel(event)
        }) {
            dismissMonitors.append(global)
        }
    }

    private func dismissIfMouseDownIsOutsidePanel(_ event: NSEvent) {
        // 触发本次会话的那次点击（时间戳不晚于会话开始）不算「点击面板外」，否则面板一弹出就被自己关掉
        guard event.timestamp > sessionStartTime else { return }
        guard let panel, panel.isVisible else { return }
        guard !panel.frame.contains(NSEvent.mouseLocation) else { return }
        statusItem.expandedInterfaceSession?.cancel()
    }

    private func removeDismissMonitors() {
        for monitor in dismissMonitors {
            NSEvent.removeMonitor(monitor)
        }
        dismissMonitors.removeAll()
    }
}
