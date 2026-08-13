import Foundation
import SwiftData

/// 日志分类
enum LogCategory: String, Codable, CaseIterable {
    /// 活动日志：记录规则触发、应用启停等用户关心的操作事件
    case activity
    /// 系统日志：记录 App 自身运行状态、权限变更、错误等
    case system
}

/// 日志级别
enum LogLevel: String, Codable, CaseIterable {
    case info
    case warning
    case error
}

/// 日志条目
/// 持久化到 SwiftData，支持按分类和时间查询
@Model
final class LogEntry {
    /// 唯一标识
    var id: UUID
    /// 日志时间戳
    var timestamp: Date
    /// 日志分类（活动 / 系统）
    var categoryRaw: String
    /// 日志级别
    var levelRaw: String
    /// 日志内容（可读描述）
    var message: String
    /// 关联的应用名称（可选）
    var relatedAppName: String?

    // MARK: - 计算属性

    var category: LogCategory {
        get { LogCategory(rawValue: categoryRaw) ?? .system }
        set { categoryRaw = newValue.rawValue }
    }

    var level: LogLevel {
        get { LogLevel(rawValue: levelRaw) ?? .info }
        set { levelRaw = newValue.rawValue }
    }

    // MARK: - 初始化

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: LogCategory = .system,
        level: LogLevel = .info,
        message: String,
        relatedAppName: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.categoryRaw = category.rawValue
        self.levelRaw = level.rawValue
        self.message = message
        self.relatedAppName = relatedAppName
    }
}
