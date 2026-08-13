import Testing
import Foundation
@testable import AutoToggle

/// 调度时区解析测试
@Suite
struct ScheduleTimeZoneTests {
    @Test("有效的时区标识解析为对应时区")
    func resolvesValidIdentifier() {
        let tz = ScheduleTimeZone.resolve(identifier: "Asia/Shanghai")
        #expect(tz.identifier == "Asia/Shanghai")
        #expect(tz.secondsFromGMT() == 8 * 3600) // 无夏令时，恒为 UTC+8
    }

    @Test("跟随系统、nil 或无效标识均回退到系统时区")
    func fallsBackToSystem() {
        let systemIdentifier = TimeZone.current.identifier
        #expect(ScheduleTimeZone.resolve(identifier: nil).identifier == systemIdentifier)
        #expect(ScheduleTimeZone.resolve(identifier: "system").identifier == systemIdentifier)
        #expect(ScheduleTimeZone.resolve(identifier: "Invalid/Zone").identifier == systemIdentifier)
    }

    @Test("calendar 使用目标时区")
    func calendarUsesTargetTimeZone() {
        let calendar = ScheduleTimeZone.calendar(for: "Asia/Tokyo")
        #expect(calendar.timeZone.identifier == "Asia/Tokyo")
    }
}
