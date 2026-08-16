import XCTest

/// UI 冒烟测试：验证应用能启动、主窗口能出现。
/// 菜单栏 NSPopover 的交互在系统菜单栏区域，XCUITest 点击状态栏图标不稳定，故这里只做启动冒烟。
final class AutoToggleUITests: XCTestCase {
    @MainActor
    func testMainWindowAppearsOnLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // 主窗口启动即打开（AppDelegate.createAndShowMainWindow）
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "主窗口未在启动后出现")
    }
}
