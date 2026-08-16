import SwiftUI
import AppKit

/// 菜单栏管理器
/// 负责菜单栏面板的状态管理
@MainActor
@Observable
final class MenuBarManager {
    // MARK: - 公开属性

    /// 当前是否处于暂停状态（所有规则暂停执行）
    var isPaused: Bool = false

    /// 活跃规则数量
    var activeRuleCount: Int = 0

    /// 注入的 UserDefaults（测试传 suiteName 隔离）
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 公开方法

    /// 切换暂停状态
    func togglePause() {
        isPaused.toggle()
        defaults.set(isPaused, forKey: "isPaused")
    }

    /// 更新菜单栏统计数据
    func updateStats(activeRules: Int) {
        activeRuleCount = activeRules
    }

    /// 退出 AutoToggle
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
