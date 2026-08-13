import Testing
import Foundation
import SwiftData
@testable import AutoToggle

/// 配置方案重命名测试（内存 SwiftData 容器，不落盘）
@Suite
struct ProfileRenameTests {
    @Test
    @MainActor
    func 重命名更新名称并去除首尾空白() throws {
        let container = try ModelContainer(
            for: Profile.self, AppRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ruleManager = RuleManager(modelContainer: container)
        let manager = ProfileManager(modelContainer: container, ruleManager: ruleManager)

        let active = try #require(manager.activeProfile)
        #expect(active.name == "配置1")

        manager.renameProfile(active, to: "  工作  ")
        #expect(manager.activeProfile?.name == "工作")
    }

    @Test
    @MainActor
    func 空名称被忽略保持原名称() throws {
        let container = try ModelContainer(
            for: Profile.self, AppRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ruleManager = RuleManager(modelContainer: container)
        let manager = ProfileManager(modelContainer: container, ruleManager: ruleManager)

        let active = try #require(manager.activeProfile)
        manager.renameProfile(active, to: "   ")
        #expect(manager.activeProfile?.name == "配置1")
    }
}
