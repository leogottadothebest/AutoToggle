import Foundation
import AppKit

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

    /// 下次规则触发时间
    private(set) var nextTriggerTime: Date?

    /// 已触发的规则记录（防止同一分钟内重复触发）: key = "ruleID:dateMinute"
    private var triggeredKeys: Set<String> = []

    // MARK: - 初始化

    init(ruleManager: RuleManager, appActionManager: AppActionManager, logManager: LogManager) {
        self.ruleManager = ruleManager
        self.appActionManager = appActionManager
        self.logManager = logManager
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

    // MARK: - 内部方法

    /// 规则调度使用的日历（依据用户选择的时区）
    private var scheduleCalendar: Calendar {
        ScheduleTimeZone.calendar(for: UserDefaults.standard.string(forKey: ScheduleTimeZone.storageKey))
    }

    /// 评估所有启用的定时规则，触发符合条件的规则
    private func evaluateRules() {
        // 检查暂停状态
        guard !isPaused() else { return }

        let now = Date()
        let calendar = scheduleCalendar
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let weekday = calendar.component(.weekday, from: now)

        // 计算并更新下次触发时间
        computeNextTriggerTime(now: now)

        // 获取所有启用规则
        let rules = ruleManager.enabledRules

        for rule in rules {
            guard let timeTrigger = rule.timeTrigger else { continue }
            guard timeTrigger.hour == hour && timeTrigger.minute == minute else { continue }
            guard timeTrigger.weekdays.isEmpty || timeTrigger.weekdays.contains(weekday) else { continue }

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
            action = "定时启动"
            appActionManager.launchApp(bundleID: rule.appBundleID)
        case .scheduledQuit:
            action = "定时退出"
            appActionManager.terminateApp(bundleID: rule.appBundleID, strategy: rule.quitStrategy)
        case .idleQuit, .idleHide:
            return // 闲置规则由 IdleDetectorManager 处理
        }

        logManager.addActivity(
            message: "\(action): \(rule.appName)",
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
            if let next = nextTrigger(for: timeTrigger, after: now, calendar: calendar) {
                if earliest == nil || next < earliest! {
                    earliest = next
                }
            }
        }

        nextTriggerTime = earliest
    }

    /// 计算单个时间触发条件的下次触发时间
    private func nextTrigger(for trigger: TimeTrigger, after now: Date, calendar: Calendar) -> Date? {
        let nowHour = calendar.component(.hour, from: now)
        let nowMinute = calendar.component(.minute, from: now)

        // 遍历未来 7 天找最近的时间
        for dayOffset in 0...7 {
            let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let candidateWeekday = calendar.component(.weekday, from: candidateDate)

            // 检查星期是否匹配
            if trigger.weekdays.isEmpty || trigger.weekdays.contains(candidateWeekday) {
                // 同一天需要检查时间是否还未过
                if dayOffset == 0 {
                    if trigger.hour > nowHour || (trigger.hour == nowHour && trigger.minute > nowMinute) {
                        return calendar.date(
                            bySettingHour: trigger.hour,
                            minute: trigger.minute,
                            second: 0,
                            of: candidateDate
                        )
                    }
                } else {
                    return calendar.date(
                        bySettingHour: trigger.hour,
                        minute: trigger.minute,
                        second: 0,
                        of: candidateDate
                    )
                }
            }
        }

        return nil
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
        UserDefaults.standard.bool(forKey: "isPaused")
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
