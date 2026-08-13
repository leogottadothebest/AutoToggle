import Foundation

/// 闲置决策输入：纯值类型，供决策引擎判断是否触发闲置动作
struct IdleDecisionInput: Equatable {
    /// 已闲置的秒数（应用闲置或系统闲置，由调用方按 scope 计算）
    var idleSeconds: TimeInterval
    /// 触发阈值（秒）
    var thresholdSeconds: TimeInterval
    /// 是否为假闲置（正在播放音频/会议中，不应关闭）
    var isFakeIdle: Bool
    /// 本闲置周期内是否已触发过（防止反复触发）
    var alreadyTriggered: Bool
    /// 目标应用是否仍在运行
    var isAppRunning: Bool
}

/// 闲置决策引擎：纯逻辑、无副作用，便于单元测试
enum IdleDecisionEngine {
    /// 判断是否应触发闲置动作
    static func shouldTrigger(_ input: IdleDecisionInput) -> Bool {
        guard input.idleSeconds >= input.thresholdSeconds else { return false }
        guard !input.isFakeIdle else { return false }
        guard !input.alreadyTriggered else { return false }
        guard input.isAppRunning else { return false }
        return true
    }

    /// 根据闲置范围选择闲置时长来源
    /// - `.app`：目标应用距上次处于前台的时间
    /// - `.system`：系统级全局闲置时间（自上次键盘/鼠标输入）
    static func idleSeconds(
        scope: IdleScope,
        appLastActive: Date,
        now: Date,
        systemIdle: TimeInterval
    ) -> TimeInterval {
        switch scope {
        case .app:
            return now.timeIntervalSince(appLastActive)
        case .system:
            return systemIdle
        }
    }

    /// 单个闲置规则的完整决策：先按 scope 求闲置时长，再套用触发条件。
    /// 纯函数、无副作用，便于单元测试覆盖 checkIdleState 的逐规则逻辑。
    static func decideTrigger(
        scope: IdleScope,
        appLastActive: Date?,
        systemIdle: TimeInterval,
        now: Date,
        thresholdSeconds: TimeInterval,
        isFakeIdle: Bool,
        alreadyTriggered: Bool,
        isAppRunning: Bool
    ) -> Bool {
        // 应用闲置范围下，必须有该应用的活跃记录才能判断
        if scope == .app, appLastActive == nil {
            return false
        }

        let idle = idleSeconds(
            scope: scope,
            appLastActive: appLastActive ?? now,
            now: now,
            systemIdle: systemIdle
        )

        return shouldTrigger(IdleDecisionInput(
            idleSeconds: idle,
            thresholdSeconds: thresholdSeconds,
            isFakeIdle: isFakeIdle,
            alreadyTriggered: alreadyTriggered,
            isAppRunning: isAppRunning
        ))
    }
}
