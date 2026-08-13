import Foundation
import SwiftData

/// 自动开关规则的主数据模型
/// 每条规则关联一个目标应用和一组触发条件
@Model
final class AppRule {
    /// 唯一标识符
    var id: UUID
    /// 目标应用 Bundle ID（如 "com.apple.Safari"）
    var appBundleID: String
    /// 目标应用名称（冗余存储，用于 UI 快速显示，避免每次都查询文件系统）
    var appName: String
    /// 规则类型：定时启动、定时退出、闲置退出、闲置隐藏
    var ruleTypeRaw: String
    /// 是否启用（禁用后规则不生效，但不删除）
    var isEnabled: Bool
    /// 创建时间
    var createdAt: Date
    /// 退出策略覆盖（nil = 使用全局设置，"normal" = 普通退出，"force" = 强制退出）
    var quitStrategyOverride: String?

    /// 所属配置方案（反向关系）
    var profile: Profile?

    /// 时间触发条件（ruleType 为 scheduledLaunch 或 scheduledQuit 时使用）
    @Attribute(.externalStorage) var timeTriggerData: Data?
    /// 闲置触发条件（ruleType 为 idleQuit 或 idleHide 时使用）
    @Attribute(.externalStorage) var idleTriggerData: Data?

    // MARK: - 计算属性

    /// 规则类型
    var ruleType: RuleType {
        get { RuleType(rawValue: ruleTypeRaw) ?? .idleQuit }
        set { ruleTypeRaw = newValue.rawValue }
    }

    /// 退出策略（由 quitStrategyOverride 推导，"force" = 三级降级强制退出）
    var quitStrategy: QuitStrategy {
        quitStrategyOverride == "force" ? .force : .normal
    }

    /// 时间触发条件
    var timeTrigger: TimeTrigger? {
        get {
            guard let data = timeTriggerData else { return nil }
            return try? JSONDecoder().decode(TimeTrigger.self, from: data)
        }
        set {
            timeTriggerData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 闲置触发条件
    var idleTrigger: IdleTrigger? {
        get {
            guard let data = idleTriggerData else { return nil }
            return try? JSONDecoder().decode(IdleTrigger.self, from: data)
        }
        set {
            idleTriggerData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 规则的简短描述（用于 UI 列表）
    var shortDescription: String {
        switch ruleType {
        case .scheduledLaunch:
            if let tt = timeTrigger {
                let weekdayStr = formatWeekdays(tt.weekdays)
                return "\(weekdayStr) \(String(format: "%02d:%02d", tt.hour, tt.minute)) 启动"
            }
            return "定时启动"
        case .scheduledQuit:
            if let tt = timeTrigger {
                let weekdayStr = formatWeekdays(tt.weekdays)
                return "\(weekdayStr) \(String(format: "%02d:%02d", tt.hour, tt.minute)) 退出"
            }
            return "定时退出"
        case .idleQuit:
            if let it = idleTrigger {
                let scope = it.scope == .system ? "系统闲置" : "闲置"
                return "\(scope) \(it.idleMinutes) 分钟后退出"
            }
            return "闲置后退出"
        case .idleHide:
            if let it = idleTrigger {
                let scope = it.scope == .system ? "系统闲置" : "闲置"
                return "\(scope) \(it.idleMinutes) 分钟后隐藏"
            }
            return "闲置后隐藏"
        }
    }

    // MARK: - 初始化

    init(
        id: UUID = UUID(),
        appBundleID: String,
        appName: String,
        ruleType: RuleType = .idleQuit,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        timeTrigger: TimeTrigger? = nil,
        idleTrigger: IdleTrigger? = nil
    ) {
        self.id = id
        self.appBundleID = appBundleID
        self.appName = appName
        self.ruleTypeRaw = ruleType.rawValue
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.timeTriggerData = timeTrigger.flatMap { try? JSONEncoder().encode($0) }
        self.idleTriggerData = idleTrigger.flatMap { try? JSONEncoder().encode($0) }
    }

    // MARK: - 辅助方法

    private func formatWeekdays(_ weekdays: Set<Int>) -> String {
        if weekdays.count == 7 || weekdays.isEmpty {
            return "每天"
        }
        if weekdays == Set([2, 3, 4, 5, 6]) {
            return "工作日"
        }
        if weekdays == Set([1, 7]) {
            return "周末"
        }
        let sorted = weekdays.sorted()
        let names = sorted.compactMap { shortWeekdayName($0) }
        return names.joined(separator: " ")
    }

    private func shortWeekdayName(_ day: Int) -> String? {
        let map: [Int: String] = [
            1: "周日", 2: "周一", 3: "周二", 4: "周三",
            5: "周四", 6: "周五", 7: "周六"
        ]
        return map[day]
    }
}
