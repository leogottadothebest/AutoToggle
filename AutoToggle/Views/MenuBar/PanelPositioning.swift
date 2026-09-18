import AppKit

/// 菜单栏展开面板的定位计算。
///
/// 纯几何，不触碰窗口，便于单元测试。macOS 27 的 expanded interface 需要我们自己把面板
/// 摆在状态项下方（系统只负责会话与键盘导航，不给锚点），因此定位规则集中在这里。
enum PanelPositioning {
    /// 面板顶边与状态项按钮底边的间距，避免与菜单栏贴死。
    static let defaultGap: CGFloat = 6

    /// 面板与屏幕可视区边缘的最小留白。
    static let defaultMargin: CGFloat = 8

    /// 计算面板应摆放的屏幕坐标 frame。
    ///
    /// - 水平：与状态项按钮中心对齐；若越出 `visibleFrame` 则夹取，保证整块面板可见
    ///   （面板比可视区还宽时贴左边留白）。
    /// - 垂直：面板顶边落在按钮底边下方 `gap` 处，即从菜单栏向下展开。
    static func frame(
        anchor: NSRect,
        panelSize: NSSize,
        visibleFrame: NSRect,
        margin: CGFloat = defaultMargin,
        gap: CGFloat = defaultGap
    ) -> NSRect {
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - margin - panelSize.width
        let centered = anchor.midX - panelSize.width / 2
        let x = min(max(centered, minX), max(minX, maxX))

        let y = anchor.minY - gap - panelSize.height

        return NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
    }
}
