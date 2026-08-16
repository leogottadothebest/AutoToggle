import Foundation
import SwiftData

/// 日志管理器
/// 负责日志的创建、查询和清理
@MainActor
@Observable
final class LogManager {
    private let modelContext: ModelContext

    // MARK: - 初始化

    init(modelContainer: ModelContainer) {
        // MED-1 修复：注册日志保留策略的默认值。
        // @AppStorage 的默认值只是读值 fallback，不会写入 UserDefaults，
        // 导致 enforceRetentionPolicy 用 integer(forKey:) 读到键缺失值 0、跳过所有清理分支。
        UserDefaults.standard.register(defaults: [
            "activityLogRetentionDays": 30,
            "activityMaxEntries": 500,
            "systemLogRetentionDays": 90,
            "systemMaxLogSizeMB": 10,
        ])
        self.modelContext = modelContainer.mainContext
    }

    // MARK: - 添加日志

    /// 添加活动日志
    /// - Parameters:
    ///   - message: 日志内容
    ///   - relatedAppName: 关联的应用名称
    func addActivity(message: String, relatedAppName: String? = nil) {
        let entry = LogEntry(
            category: .activity,
            level: .info,
            message: message,
            relatedAppName: relatedAppName
        )
        modelContext.insert(entry)
        saveIfNeeded()
    }

    /// 添加系统日志
    /// - Parameters:
    ///   - message: 日志内容
    ///   - level: 日志级别
    func addSystem(message: String, level: LogLevel = .info) {
        let entry = LogEntry(
            category: .system,
            level: level,
            message: message
        )
        modelContext.insert(entry)
        saveIfNeeded()
    }

    // MARK: - 查询

    /// 查询最近 N 条日志
    func recentEntries(limit: Int = 20) -> [LogEntry] {
        var descriptor = FetchDescriptor<LogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 按分类查询日志
    func entries(for category: LogCategory, limit: Int = 100) -> [LogEntry] {
        var descriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate { $0.categoryRaw == category.rawValue },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 清除指定分类的全部日志
    func clear(category: LogCategory) {
        for entry in entries(for: category, limit: 10000) {
            modelContext.delete(entry)
        }
        saveIfNeeded()
    }

    /// 清除超过指定天数的活动日志
    func clearActivity(olderThan days: Int) {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-TimeInterval(days * 86400))
        deleteEntries(category: .activity, olderThan: cutoff)
    }

    /// 清除超过指定天数的系统日志
    func clearSystem(olderThan days: Int) {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-TimeInterval(days * 86400))
        deleteEntries(category: .system, olderThan: cutoff)
    }

    /// 强制日志条数上限（删除最旧的超出上限的条目）
    func enforceMaxCount(category: LogCategory, max: Int) {
        guard max > 0 else { return }
        let allEntries = entries(for: category, limit: 10000)
        guard allEntries.count > max else { return }
        let toDelete = allEntries.suffix(from: max)
        for entry in toDelete {
            modelContext.delete(entry)
        }
        saveIfNeeded()
    }

    /// 强制日志文件大小上限（删除最旧的超出大小上限的条目）
    func enforceMaxSize(category: LogCategory, maxSizeMB: Int) {
        guard maxSizeMB > 0 else { return }
        let maxBytes = maxSizeMB * 1_048_576
        let allEntries = entries(for: category, limit: 10000)
        guard !allEntries.isEmpty else { return }

        // 从旧到新排序
        let sorted = allEntries.sorted { $0.timestamp < $1.timestamp }
        var totalSize = 0
        // 从最新到最旧计算累计大小
        let reversed = sorted.reversed()
        for entry in reversed {
            totalSize += estimateEntrySize(entry)
            if totalSize > maxBytes {
                modelContext.delete(entry)
            }
        }
        saveIfNeeded()
    }

    /// 估算单条日志条目的大小（字节）
    private func estimateEntrySize(_ entry: LogEntry) -> Int {
        let baseSize = 100 // UUID + Date + enum strings + protocol overhead
        let messageSize = entry.message.utf8.count
        let appNameSize = entry.relatedAppName?.utf8.count ?? 0
        return baseSize + messageSize + appNameSize
    }

    /// 执行完整的日志保留策略（从 UserDefaults 读取设置）
    func enforceRetentionPolicy() {
        let activityDays = UserDefaults.standard.integer(forKey: "activityLogRetentionDays")
        let systemDays = UserDefaults.standard.integer(forKey: "systemLogRetentionDays")
        let activityMax = UserDefaults.standard.integer(forKey: "activityMaxEntries")
        let systemMaxSizeMB = UserDefaults.standard.integer(forKey: "systemMaxLogSizeMB")

        if activityDays > 0 { clearActivity(olderThan: activityDays) }
        if systemDays > 0 { clearSystem(olderThan: systemDays) }
        if activityMax > 0 { enforceMaxCount(category: .activity, max: activityMax) }
        if systemMaxSizeMB > 0 { enforceMaxSize(category: .system, maxSizeMB: systemMaxSizeMB) }
    }

    // MARK: - 内部

    private func deleteEntries(category: LogCategory, olderThan cutoff: Date) {
        let allEntries = entries(for: category, limit: 10000)
        for entry in allEntries where entry.timestamp < cutoff {
            modelContext.delete(entry)
        }
        saveIfNeeded()
    }

    private func saveIfNeeded() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("保存日志失败: \(error.localizedDescription, privacy: .public)")
        }
    }
}
