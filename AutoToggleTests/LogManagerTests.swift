import Testing
import Foundation
import SwiftData
@testable import AutoToggle

/// 日志管理器测试（分类过滤、排序、保留策略裁剪）
@Suite
struct LogManagerTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: LogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("按分类查询过滤正确")
    @MainActor
    func entriesFilterByCategory() throws {
        let container = try makeContainer()
        let manager = LogManager(modelContainer: container)
        manager.addActivity(message: "activity")
        manager.addSystem(message: "system", level: .info)

        #expect(manager.entries(for: .activity).count == 1)
        #expect(manager.entries(for: .system).count == 1)
    }

    @Test("recentEntries 按时间倒序返回")
    @MainActor
    func recentEntriesSortedDescending() throws {
        let container = try makeContainer()
        let manager = LogManager(modelContainer: container)
        manager.addSystem(message: "first")
        manager.addSystem(message: "second")

        let entries = manager.recentEntries(limit: 10)
        #expect(entries.count == 2)
        #expect(entries[0].message == "second")
    }

    @Test("enforceMaxCount 裁剪最旧条目")
    @MainActor
    func enforceMaxCountTrimsOldest() throws {
        let container = try makeContainer()
        let manager = LogManager(modelContainer: container)
        for i in 0..<5 {
            manager.addSystem(message: "entry \(i)")
        }
        #expect(manager.entries(for: .system).count == 5)

        manager.enforceMaxCount(category: .system, max: 3)
        #expect(manager.entries(for: .system).count == 3)
    }

    @Test("clearActivity 移除超期条目，保留新条目")
    @MainActor
    func clearActivityRemovesOldEntries() throws {
        let container = try makeContainer()
        let manager = LogManager(modelContainer: container)
        let context = container.mainContext

        context.insert(LogEntry(
            timestamp: Date().addingTimeInterval(-3 * 86400),
            category: .activity,
            level: .info,
            message: "old"
        ))
        context.insert(LogEntry(
            timestamp: Date(),
            category: .activity,
            level: .info,
            message: "new"
        ))
        try context.save()

        manager.clearActivity(olderThan: 1)
        let remaining = manager.entries(for: .activity)
        #expect(remaining.count == 1)
        #expect(remaining.first?.message == "new")
    }
}
