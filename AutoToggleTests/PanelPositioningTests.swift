import Testing
import AppKit
@testable import AutoToggle

/// 菜单栏展开面板的定位计算测试
@Suite
struct PanelPositioningTests {
    /// 主屏可视区（菜单栏以下）
    private let mainVisible = NSRect(x: 0, y: 0, width: 1710, height: 997)
    private let panelSize = NSSize(width: 300, height: 400)

    @Test("面板水平居中对齐状态项、顶边贴在按钮下方")
    func centersUnderAnchor() {
        let anchor = NSRect(x: 1000, y: 1000, width: 22, height: 29)
        let frame = PanelPositioning.frame(anchor: anchor, panelSize: panelSize, visibleFrame: mainVisible)

        #expect(frame.midX == anchor.midX)
        #expect(frame.maxY == anchor.minY - PanelPositioning.defaultGap)
        #expect(frame.size == panelSize)
    }

    @Test("靠屏幕右边缘时夹取，保证整块面板可见")
    func clampsAtRightEdge() {
        let anchor = NSRect(x: 1689, y: 1000, width: 22, height: 29)
        let frame = PanelPositioning.frame(anchor: anchor, panelSize: panelSize, visibleFrame: mainVisible)

        #expect(frame.maxX == mainVisible.maxX - PanelPositioning.defaultMargin)
        #expect(frame.midX < anchor.midX)
    }

    @Test("靠屏幕左边缘时夹取，保证整块面板可见")
    func clampsAtLeftEdge() {
        let anchor = NSRect(x: 0, y: 1000, width: 22, height: 29)
        let frame = PanelPositioning.frame(anchor: anchor, panelSize: panelSize, visibleFrame: mainVisible)

        #expect(frame.minX == mainVisible.minX + PanelPositioning.defaultMargin)
    }

    @Test("面板比可视区还宽时贴左边留白，而不是算出负坐标")
    func clampsWhenPanelWiderThanVisibleFrame() {
        let wide = NSSize(width: 2000, height: 400)
        let anchor = NSRect(x: 800, y: 1000, width: 22, height: 29)
        let frame = PanelPositioning.frame(anchor: anchor, panelSize: wide, visibleFrame: mainVisible)

        #expect(frame.minX == mainVisible.minX + PanelPositioning.defaultMargin)
    }

    @Test("多屏：夹取依据传入屏的可视区，而不是主屏")
    func clampsAgainstGivenScreen() {
        let secondaryVisible = NSRect(x: 1710, y: 0, width: 1710, height: 1107)
        let anchor = NSRect(x: 2200, y: 1078, width: 22, height: 29)
        let frame = PanelPositioning.frame(anchor: anchor, panelSize: panelSize, visibleFrame: secondaryVisible)

        #expect(frame.midX == anchor.midX) // 副屏中间，无需夹取
        #expect(frame.minX >= secondaryVisible.minX + PanelPositioning.defaultMargin)
    }

    @Test("副屏右边缘同样会夹取")
    func clampsAtSecondaryScreenRightEdge() {
        let secondaryVisible = NSRect(x: 1710, y: 0, width: 1710, height: 1107)
        let anchor = NSRect(x: 3400, y: 1078, width: 22, height: 29)
        let frame = PanelPositioning.frame(anchor: anchor, panelSize: panelSize, visibleFrame: secondaryVisible)

        #expect(frame.maxX == secondaryVisible.maxX - PanelPositioning.defaultMargin)
    }
}
