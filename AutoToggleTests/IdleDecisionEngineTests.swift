import Testing
import Foundation
@testable import AutoToggle

/// 闲置决策引擎的纯逻辑测试
@Suite
struct IdleDecisionEngineTests {
    private func makeInput(
        idleSeconds: TimeInterval = 60,
        thresholdSeconds: TimeInterval = 30,
        isFakeIdle: Bool = false,
        alreadyTriggered: Bool = false,
        isAppRunning: Bool = true
    ) -> IdleDecisionInput {
        IdleDecisionInput(
            idleSeconds: idleSeconds,
            thresholdSeconds: thresholdSeconds,
            isFakeIdle: isFakeIdle,
            alreadyTriggered: alreadyTriggered,
            isAppRunning: isAppRunning
        )
    }

    @Test("闲置达到阈值且无阻碍时触发")
    func triggersWhenIdleEnough() {
        #expect(IdleDecisionEngine.shouldTrigger(makeInput(idleSeconds: 30, thresholdSeconds: 30)))
        #expect(IdleDecisionEngine.shouldTrigger(makeInput(idleSeconds: 120, thresholdSeconds: 30)))
    }

    @Test("未达到阈值不触发")
    func doesNotTriggerBelowThreshold() {
        #expect(!IdleDecisionEngine.shouldTrigger(makeInput(idleSeconds: 29, thresholdSeconds: 30)))
    }

    @Test("假闲置（音频/会议）不触发")
    func doesNotTriggerOnFakeIdle() {
        #expect(!IdleDecisionEngine.shouldTrigger(makeInput(isFakeIdle: true)))
    }

    @Test("本闲置周期内已触发过则不重复触发")
    func doesNotTriggerWhenAlreadyTriggered() {
        #expect(!IdleDecisionEngine.shouldTrigger(makeInput(alreadyTriggered: true)))
    }

    @Test("应用未运行时不触发")
    func doesNotTriggerWhenAppNotRunning() {
        #expect(!IdleDecisionEngine.shouldTrigger(makeInput(isAppRunning: false)))
    }

    @Test("scope 决定闲置时长来源")
    func idleSecondsByScope() {
        let now = Date(timeIntervalSince1970: 1_000)
        let lastActive = now.addingTimeInterval(-120) // 2 分钟前

        // 应用闲置：取「距上次前台」的时间
        #expect(IdleDecisionEngine.idleSeconds(
            scope: .app, appLastActive: lastActive, now: now, systemIdle: 999
        ) == 120)

        // 系统闲置：取系统全局闲置时间（忽略 appLastActive）
        #expect(IdleDecisionEngine.idleSeconds(
            scope: .system, appLastActive: lastActive, now: now, systemIdle: 45
        ) == 45)
    }

    // MARK: - decideTrigger（逐规则完整决策）

    @Test("应用闲置达到阈值时触发")
    func decideTriggerAppScopeIdle() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(IdleDecisionEngine.decideTrigger(
            scope: .app, appLastActive: now.addingTimeInterval(-600), systemIdle: 0,
            now: now, thresholdSeconds: 300, isFakeIdle: false,
            alreadyTriggered: false, isAppRunning: true
        ))
    }

    @Test("应用闲置缺少活跃记录时不触发")
    func decideTriggerAppScopeMissingActive() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(!IdleDecisionEngine.decideTrigger(
            scope: .app, appLastActive: nil, systemIdle: 999,
            now: now, thresholdSeconds: 300, isFakeIdle: false,
            alreadyTriggered: false, isAppRunning: true
        ))
    }

    @Test("系统闲置依据系统全局闲置时间触发")
    func decideTriggerSystemScope() {
        let now = Date(timeIntervalSince1970: 1_000)
        // 系统闲置 600s >= 阈值 300s，即使应用从未在前台也触发
        #expect(IdleDecisionEngine.decideTrigger(
            scope: .system, appLastActive: nil, systemIdle: 600,
            now: now, thresholdSeconds: 300, isFakeIdle: false,
            alreadyTriggered: false, isAppRunning: true
        ))
        // 系统未闲置则不触发
        #expect(!IdleDecisionEngine.decideTrigger(
            scope: .system, appLastActive: nil, systemIdle: 60,
            now: now, thresholdSeconds: 300, isFakeIdle: false,
            alreadyTriggered: false, isAppRunning: true
        ))
    }

    @Test("假闲置或已触发或未运行时不触发")
    func decideTriggerBlockers() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(!IdleDecisionEngine.decideTrigger(
            scope: .app, appLastActive: now.addingTimeInterval(-600), systemIdle: 0,
            now: now, thresholdSeconds: 300, isFakeIdle: true,
            alreadyTriggered: false, isAppRunning: true
        ))
        #expect(!IdleDecisionEngine.decideTrigger(
            scope: .app, appLastActive: now.addingTimeInterval(-600), systemIdle: 0,
            now: now, thresholdSeconds: 300, isFakeIdle: false,
            alreadyTriggered: true, isAppRunning: true
        ))
        #expect(!IdleDecisionEngine.decideTrigger(
            scope: .app, appLastActive: now.addingTimeInterval(-600), systemIdle: 0,
            now: now, thresholdSeconds: 300, isFakeIdle: false,
            alreadyTriggered: false, isAppRunning: false
        ))
    }
}
