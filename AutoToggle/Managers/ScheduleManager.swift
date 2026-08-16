import Foundation
import AppKit

/// 定时任务快照（供菜单栏等 UI 展示）
struct UpcomingScheduledTrigger: Identifiable {
    let id: UUID
    let appName: String
    let bundleID: String
    /// true = 定时启动，false = 定时退出
    let isLaunch: Bool
    /// 规则是否启用（禁用规则仍展示，供右侧开关切换）
    let isEnabled: Bool
    /// 下次触发时间
    let date: Date
}

/// 定时调度管理器
/// 负责 Timer 驱动的规则评估和触发执行
@MainActor
@Observable
final class ScheduleManager {
    /// 规则管理器引用
    private let ruleManager: RuleManager
    /// 应用操作管理器引用
    private let appActionManager: AppActionManager
    /// 日志管理器引用
    private let logManager: LogManager

    /// 主调度 Timer（每分钟触发一次）
    private var timer: Timer?

    /// 注入的 UserDefaults（测试传 suiteName 隔离，生产用 .standard）
    private let defaults: UserDefaults

    /// 下次规则触发时间
    private(set) var nextTriggerTime: Date?

    /// 已触发的规则记录（防止同一分钟内重复触发）: key = "ruleID:dateMinute"
    private var triggeredKeys: Set<String> = []

    // MARK: - 初始化

    init(
        ruleManager: RuleManager,
        appActionManager: AppActionManager,
        logManager: LogManager,
        defaults: UserDefaults = .standard
    ) {
        self.ruleManager = ruleManager
        self.appActionManager = appActionManager
        self.logManager = logManager
        self.defaults = defaults
    }

    // MARK: - 公开方法

    /// 启动定时调度
    func startScheduling() {
        stopScheduling()

        // 每分钟触发一次检查
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            // MED-2 修复：显式跳回 MainActor，避免在非隔离上下文同步调用 @MainActor 方法
            Task { @MainActor [weak self] in
                self?.evaluateRules()
            }
        }

        // 立即执行一次评估
        evaluateRules()
    }

    /// 停止定时调度
    func stopScheduling() {
        timer?.invalidate()
        timer = nil
    }

    /// 时区等设置变化后，立即重新评估一次调度（无需等待下一分钟）
    func reevaluate() {
        evaluateRules()
    }

    /// 未来即将触发的定时任务（含禁用规则，按触发时间升序，最多 limit 条）
    func upcomingScheduledTriggers(limit: Int = 5) -> [UpcomingScheduledTrigger] {
        let now = Date()
        let calendar = scheduleCalendar
        var results: [UpcomingScheduledTrigger] = []

        // 遍历全部规则（含禁用），让关闭的定时任务仍显示在菜单栏、可通过右侧开关重新启用
        for rule in ruleManager.allRules where rule.ruleType.isScheduled {
            guard let trigger = rule.timeTrigger,
                  let next = ScheduleEngine.nextTrigger(for: trigger, after: now, calendar: calendar) else { continue }
            results.append(UpcomingScheduledTrigger(
                id: rule.id,
                appName: rule.appName,
                bundleID: rule.appBundleID,
                isLaunch: rule.ruleType == .scheduledLaunch,
                isEnabled: rule.isEnabled,
                date: next
            ))
        }

        return results.sorted { $0.date < $1.date }.prefix(limit).map { $0 }
    }

    // MARK: - 内部方法

    /// 规则调度使用的日历（依据用户选择的时区）
    private var scheduleCalendar: Calendar {
        ScheduleTimeZone.calendar(for: defaults.string(forKey: ScheduleTimeZone.storageKey))
    }

    /// 评估所有启用的定时规则，触发符合条件的规则。
    /// 内部可见（非 private）以便测试注入 `now` 精确驱动。
    func evaluateRules(at now: Date = Date()) {
        // 检查暂停状态
        guard !isPaused() else { return }

        let calendar = scheduleCalendar
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // 计算并更新下次触发时间
        computeNextTriggerTime(now: now)

        // 获取所有启用规则
        let rules = ruleManager.enabledRules

        for rule in rules {
            guard let timeTrigger = rule.timeTrigger else { continue }
            guard ScheduleEngine.matches(timeTrigger, at: now, calendar: calendar) else { continue }

            // 防重复触发：同一条规则在同一分钟内只触发一次
            let triggerKey = "\(rule.id.uuidString):\(hour):\(minute)"
            guard !triggeredKeys.contains(triggerKey) else { continue }

            triggeredKeys.insert(triggerKey)

            // 执行规则
            executeRule(rule)
        }

        // 每分钟清理过期的触发记录
        cleanupTriggeredKeys(currentHour: hour, currentMinute: minute)
    }

    /// 执行单条规则
    private func executeRule(_ rule: AppRule) {
        let action: String
        switch rule.ruleType {
        case .scheduledLaunch:
            action = String(localized: "ruleType.scheduledLaunch")
            appActionManager.launchApp(bundleID: rule.appBundleID)
        case .scheduledQuit:
            action = String(localized: "ruleType.scheduledQuit")
            appActionManager.terminateApp(bundleID: rule.appBundleID, strategy: rule.quitStrategy)
        case .idleQuit, .idleHide:
            return // 闲置规则由 IdleDetectorManager 处理
        }

        logManager.addActivity(
            message: String(localized: "log.action \(action) \(rule.appName)"),
            relatedAppName: rule.appName
        )
    }

    /// 计算下次触发时间
    private func computeNextTriggerTime(now: Date) {
        let calendar = scheduleCalendar
        var earliest: Date?

        for rule in ruleManager.enabledRules {
            guard let timeTrigger = rule.timeTrigger else { continue }

            // 计算该规则的下次触发时间
            if let next = ScheduleEngine.nextTrigger(for: timeTrigger, after: now, calendar: calendar) {
                if earliest == nil || next < earliest! {
                    earliest = next
                }
            }
        }

        nextTriggerTime = earliest
    }

    /// 清理过期的触发记录（保留当前小时的记录）
    private func cleanupTriggeredKeys(currentHour: Int, currentMinute: Int) {
        let currentKey = "\(currentHour):\(currentMinute)"
        triggeredKeys = triggeredKeys.filter { key in
            key.hasSuffix(currentKey)
        }
    }

    /// 检查是否处于暂停状态
    private func isPaused() -> Bool {
        defaults.bool(forKey: "isPaused")
    }
}

/// 调度时区解析
enum ScheduleTimeZone {
    /// UserDefaults 存储键
    static let storageKey = "scheduleTimeZone"
    /// 「跟随系统」的标识值
    static let systemIdentifier = "system"

    /// 把存储的时区标识解析为 TimeZone；无效或「跟随系统」时回退系统时区
    static func resolve(identifier: String?) -> TimeZone {
        if let identifier,
           identifier != systemIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }
        return .current
    }

    /// 构造用于规则调度的公历日历（带目标时区）
    static func calendar(for identifier: String?) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = resolve(identifier: identifier)
        return calendar
    }
}
