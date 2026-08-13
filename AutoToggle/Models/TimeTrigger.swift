import Foundation

/// 规则类型
enum RuleType: String, Codable, CaseIterable {
    /// 定时启动
    case scheduledLaunch
    /// 定时退出
    case scheduledQuit
    /// 闲置后退出
    case idleQuit
    /// 闲置后隐藏
    case idleHide

    /// 是否为定时类型
    var isScheduled: Bool {
        self == .scheduledLaunch || self == .scheduledQuit
    }

    /// 是否为闲置类型
    var isIdle: Bool {
        self == .idleQuit || self == .idleHide
    }
}

/// 时间触发条件
/// 定义规则在什么时间触发
struct TimeTrigger: Codable, Equatable {
    /// 小时（0-23）
    var hour: Int
    /// 分钟（0-59）
    var minute: Int
    /// 触发星期（1=周日, 2=周一, ..., 7=周六，遵循 Calendar.current.weekday 规范）
    var weekdays: Set<Int>

    init(hour: Int = 9, minute: Int = 0, weekdays: Set<Int> = [2, 3, 4, 5, 6]) {
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
    }
}

/// 闲置检测范围
/// 决定「闲置」如何被判定：目标应用未处于前台，或整个系统无键盘/鼠标输入
enum IdleScope: String, Codable, CaseIterable {
    /// 应用闲置：目标应用在指定分钟内未处于前台
    case app
    /// 系统闲置：整个系统在指定分钟内无键盘/鼠标输入（全局闲置）
    case system
}

/// 闲置触发条件
/// 定义应用闲置多久后触发动作
struct IdleTrigger: Codable, Equatable {
    /// 闲置分钟数
    var idleMinutes: Int
    /// 闲置检测范围（默认应用闲置，与历史数据兼容）
    var scope: IdleScope

    init(idleMinutes: Int = 10, scope: IdleScope = .app) {
        self.idleMinutes = idleMinutes
        self.scope = scope
    }

    // MARK: - 向后兼容解码

    /// 旧版本持久化数据不包含 `scope` 字段，需兼容解码为默认值
    private enum CodingKeys: String, CodingKey {
        case idleMinutes
        case scope
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idleMinutes = try container.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? 10
        scope = try container.decodeIfPresent(IdleScope.self, forKey: .scope) ?? .app
    }
}
