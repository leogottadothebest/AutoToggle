import Testing
import Foundation
import SwiftData
@testable import AutoToggle

/// 规则管理器 CRUD 测试（内存 SwiftData 容器）
@Suite
struct RuleManagerTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AppRule.self, LogEntry.self, Profile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeRule(bundleID: String = "com.apple.Safari", enabled: Bool = true) -> AppRule {
        AppRule(appBundleID: bundleID, appName: "Safari", ruleType: .idleQuit, isEnabled: enabled)
    }

    @Test("添加规则后进入 allRules 与 enabledRules")
    @MainActor
    func addRuleAppearsInLists() throws {
        let container = try makeContainer()
        let manager = RuleManager(modelContainer: container)
        #expect(manager.allRules.isEmpty)

        manager.addRule(makeRule())
        #expect(manager.allRules.count == 1)
        #expect(manager.enabledRules.count == 1)
    }

    @Test("切换启用状态同步 enabledRules")
    @MainActor
    func toggleRuleUpdatesEnabledRules() throws {
        let container = try makeContainer()
        let manager = RuleManager(modelContainer: container)
        let rule = makeRule()
        manager.addRule(rule)

        manager.toggleRule(rule)
        #expect(manager.allRules.count == 1)
        #expect(manager.enabledRules.isEmpty)

        manager.toggleRule(id: rule.id)
        #expect(manager.enabledRules.count == 1)
    }

    @Test("删除规则后从列表移除")
    @MainActor
    func deleteRuleRemovesFromLists() throws {
        let container = try makeContainer()
        let manager = RuleManager(modelContainer: container)
        let rule = makeRule()
        manager.addRule(rule)
        #expect(manager.allRules.count == 1)

        manager.deleteRule(rule)
        #expect(manager.allRules.isEmpty)
    }

    @Test("managedBundleIDs 返回启用规则的 bundle ID 集合")
    @MainActor
    func managedBundleIDsReflectsEnabledRules() throws {
        let container = try makeContainer()
        let manager = RuleManager(modelContainer: container)
        manager.addRule(makeRule(bundleID: "com.apple.Safari"))
        manager.addRule(makeRule(bundleID: "com.google.Chrome", enabled: false))

        #expect(manager.managedBundleIDs() == Set(["com.apple.Safari"]))
    }
}
