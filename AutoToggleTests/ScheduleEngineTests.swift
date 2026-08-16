import Testing
import Foundation
@testable import AutoToggle

/// 定时调度纯引擎测试（日期数学，无副作用）
@Suite
struct ScheduleEngineTests {
    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        Self.cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("命中：小时/分钟/星期全部匹配")
    func matchesWhenAllMatch() {
        let now = date(2026, 8, 16, 10, 30)
        let weekday = Self.cal.component(.weekday, from: now)
        let trigger = TimeTrigger(hour: 10, minute: 30, weekdays: [weekday])
        #expect(ScheduleEngine.matches(trigger, at: now, calendar: Self.cal))
    }

    @Test("未命中：小时不同")
    func mismatchWhenHourDiffers() {
        let now = date(2026, 8, 16, 10, 30)
        let weekday = Self.cal.component(.weekday, from: now)
        let trigger = TimeTrigger(hour: 11, minute: 30, weekdays: [weekday])
        #expect(!ScheduleEngine.matches(trigger, at: now, calendar: Self.cal))
    }

    @Test("未命中：星期不在集合")
    func mismatchWhenWeekdayNotInSet() {
        let now = date(2026, 8, 16, 10, 30)
        let weekday = Self.cal.component(.weekday, from: now)
        let other = weekday % 7 + 1
        let trigger = TimeTrigger(hour: 10, minute: 30, weekdays: [other])
        #expect(!ScheduleEngine.matches(trigger, at: now, calendar: Self.cal))
    }

    @Test("空星期集合表示每天命中")
    func emptyWeekdaysMeansEveryDay() {
        let now = date(2026, 8, 16, 10, 30)
        let trigger = TimeTrigger(hour: 10, minute: 30, weekdays: [])
        #expect(ScheduleEngine.matches(trigger, at: now, calendar: Self.cal))
    }

    @Test("下次触发：同日未来时间命中当天")
    func nextTriggerSameDayFuture() {
        let now = date(2026, 8, 16, 9, 0)
        let trigger = TimeTrigger(hour: 10, minute: 30, weekdays: [])
        let next = ScheduleEngine.nextTrigger(for: trigger, after: now, calendar: Self.cal)
        #expect(next == date(2026, 8, 16, 10, 30))
    }

    @Test("下次触发：同日已过则滚动到次日")
    func nextTriggerSameDayPastRollsOver() {
        let now = date(2026, 8, 16, 9, 0)
        let trigger = TimeTrigger(hour: 8, minute: 0, weekdays: [])
        let next = ScheduleEngine.nextTrigger(for: trigger, after: now, calendar: Self.cal)
        #expect(next == date(2026, 8, 17, 8, 0))
    }

    @Test("下次触发：星期限制跳到下一个匹配日")
    func nextTriggerRespectsWeekday() {
        let now = date(2026, 8, 16, 9, 0)
        let todayWeekday = Self.cal.component(.weekday, from: now)
        let tomorrowWeekday = todayWeekday % 7 + 1
        let trigger = TimeTrigger(hour: 10, minute: 0, weekdays: [tomorrowWeekday])
        let next = ScheduleEngine.nextTrigger(for: trigger, after: now, calendar: Self.cal)

        let tomorrow = Self.cal.date(byAdding: .day, value: 1, to: now)!
        let expected = Self.cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!
        #expect(next == expected)
    }
}
