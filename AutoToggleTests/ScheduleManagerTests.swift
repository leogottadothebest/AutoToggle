import Testing
import Foundation
import SwiftData
@testable import AutoToggle

/// 定时调度管理器集成测试（去重、启用过滤、动作分发）
@Suite
struct ScheduleManagerTests {
    @Test("定时规则在触发分钟内只执行一次（去重）")
    @MainActor
    func scheduledRuleFiresOncePerMinute() throws {
        let container = try ModelContainer(
            for: AppRule.self, LogEntry.self, Profile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ruleManager = RuleManager(modelContainer: container)
        let logManager = LogManager(modelContainer: container)

        let controller = FakeAppController()
        controller.urlsByBundleID["com.apple.Safari"] = URL(fileURLWithPath: "/Applications/Safari.app")
        let action = AppActionManager()
        action.configure(controller: controller)

        let defaults = UserDefaults(suiteName: "test.schedule.\(UUID().uuidString)")!
        let schedule = ScheduleManager(
            ruleManager: ruleManager,
            appActionManager: action,
            logManager: logManager,
            defaults: defaults
        )

        ruleManager.addRule(AppRule(
            appBundleID: "com.apple.Safari",
            appName: "Safari",
            ruleType: .scheduledLaunch,
            timeTrigger: TimeTrigger(hour: 10, minute: 30, weekdays: [])
        ))

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 16, hour: 10, minute: 30))!

        schedule.evaluateRules(at: now)
        #expect(controller.openedURLs.count == 1)

        // 同一分钟内再次评估不重复触发（去重键为 ruleID:小时:分钟）
        schedule.evaluateRules(at: now.addingTimeInterval(10))
        #expect(controller.openedURLs.count == 1)

        schedule.evaluateRules(at: now.addingTimeInterval(30))
        #expect(controller.openedURLs.count == 1)
    }

    @Test("禁用规则不触发")
    @MainActor
    func disabledRuleDoesNotFire() throws {
        let container = try ModelContainer(
            for: AppRule.self, LogEntry.self, Profile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ruleManager = RuleManager(modelContainer: container)
        let logManager = LogManager(modelContainer: container)

        let controller = FakeAppController()
        controller.urlsByBundleID["com.apple.Safari"] = URL(fileURLWithPath: "/Applications/Safari.app")
        let action = AppActionManager()
        action.configure(controller: controller)

        let defaults = UserDefaults(suiteName: "test.schedule.\(UUID().uuidString)")!
        let schedule = ScheduleManager(
            ruleManager: ruleManager,
            appActionManager: action,
            logManager: logManager,
            defaults: defaults
        )

        let rule = AppRule(
            appBundleID: "com.apple.Safari",
            appName: "Safari",
            ruleType: .scheduledLaunch,
            isEnabled: false,
            timeTrigger: TimeTrigger(hour: 10, minute: 30, weekdays: [])
        )
        ruleManager.addRule(rule)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 16, hour: 10, minute: 30))!

        schedule.evaluateRules(at: now)
        #expect(controller.openedURLs.isEmpty)
    }
}
