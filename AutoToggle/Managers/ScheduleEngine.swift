import Foundation

/// 定时调度纯引擎：无副作用、可注入日历，便于单元测试。
/// 从 ScheduleManager 抽出的日期数学，遵循 IdleDecisionEngine 的纯 enum 先例。
enum ScheduleEngine {
    /// 判断触发条件在指定时刻是否命中（小时 / 分钟 / 星期）。
    /// `weekdays` 为空表示「每天」。
    static func matches(_ trigger: TimeTrigger, at date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let weekday = calendar.component(.weekday, from: date)
        guard trigger.hour == hour, trigger.minute == minute else { return false }
        guard trigger.weekdays.isEmpty || trigger.weekdays.contains(weekday) else { return false }
        return true
    }

    /// 计算单个时间触发条件的下次触发时间（未来 7 天内最近一次命中）。
    /// 找不到（如 weekday 为空且未来 7 天无匹配）返回 nil。
    static func nextTrigger(for trigger: TimeTrigger, after now: Date, calendar: Calendar) -> Date? {
        let nowHour = calendar.component(.hour, from: now)
        let nowMinute = calendar.component(.minute, from: now)

        for dayOffset in 0...7 {
            let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let candidateWeekday = calendar.component(.weekday, from: candidateDate)

            if trigger.weekdays.isEmpty || trigger.weekdays.contains(candidateWeekday) {
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
}
