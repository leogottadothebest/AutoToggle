import Testing
import Foundation
@testable import AutoToggle

/// SleepPreventionManager 的状态与持久化测试（通过假断言提供者注入，无需真实电源断言）
@Suite
struct SleepPreventionManagerTests {
    /// 每个测试前清空持久化状态，避免串扰
    private func resetDefaults() {
        UserDefaults.standard.removeObject(forKey: "preventSystemSleep")
        UserDefaults.standard.removeObject(forKey: "preventDisplaySleep")
    }

    @Test
    @MainActor
    func 开启系统休眠会创建断言并持久化() {
        resetDefaults()
        let provider = FakePowerAssertionProvider()
        let manager = SleepPreventionManager(assertionProvider: provider)
        #expect(!manager.isPreventingSystemSleep)

        manager.setSystemSleepPrevention(true)
        #expect(manager.isPreventingSystemSleep)
        #expect(provider.createdTypes.contains(.systemSleep))
        #expect(UserDefaults.standard.bool(forKey: "preventSystemSleep"))
    }

    @Test
    @MainActor
    func 关闭会释放对应的断言() {
        resetDefaults()
        let provider = FakePowerAssertionProvider()
        let manager = SleepPreventionManager(assertionProvider: provider)

        manager.setSystemSleepPrevention(true)
        let createdID = provider.createdIDs.first
        manager.setSystemSleepPrevention(false)

        #expect(!manager.isPreventingSystemSleep)
        #expect(!UserDefaults.standard.bool(forKey: "preventSystemSleep"))
        if let createdID {
            #expect(provider.released == [createdID])
        }
    }

    @Test
    @MainActor
    func 重复开启不会重复创建断言() {
        resetDefaults()
        let provider = FakePowerAssertionProvider()
        let manager = SleepPreventionManager(assertionProvider: provider)

        manager.setSystemSleepPrevention(true)
        manager.setSystemSleepPrevention(true) // 幂等，不重复创建
        #expect(provider.createdIDs.count == 1)
    }

    @Test
    @MainActor
    func init从持久化恢复开启态() {
        resetDefaults()
        UserDefaults.standard.set(true, forKey: "preventSystemSleep")

        let provider = FakePowerAssertionProvider()
        let manager = SleepPreventionManager(assertionProvider: provider)

        #expect(manager.isPreventingSystemSleep)
        #expect(provider.createdTypes.contains(.systemSleep))
    }

    @Test
    @MainActor
    func 显示器档独立于系统休眠档() {
        resetDefaults()
        let provider = FakePowerAssertionProvider()
        let manager = SleepPreventionManager(assertionProvider: provider)

        manager.setDisplaySleepPrevention(true)
        #expect(manager.isPreventingDisplaySleep)
        #expect(!manager.isPreventingSystemSleep)
        #expect(provider.createdTypes.contains(.displaySleep))
        #expect(!provider.createdTypes.contains(.systemSleep))
    }

    @Test
    @MainActor
    func toggleSystemSleep来回切换() {
        resetDefaults()
        let provider = FakePowerAssertionProvider()
        let manager = SleepPreventionManager(assertionProvider: provider)

        manager.toggleSystemSleep() // 关 → 开
        #expect(manager.isPreventingSystemSleep)

        manager.toggleSystemSleep() // 开 → 关
        #expect(!manager.isPreventingSystemSleep)
    }

    @Test
    func 真实断言提供者可创建并释放断言() {
        let provider = IOPMAssertionProvider()
        let id = provider.createAssertion(type: .systemSleep, reason: "AutoToggle 测试断言")
        #expect(id != nil)
        if let id {
            provider.releaseAssertion(id)
        }
    }
}

/// 测试用假断言提供者：记录创建/释放调用，返回递增 ID
final class FakePowerAssertionProvider: PowerAssertionProviding, @unchecked Sendable {
    private(set) var createdTypes: [SleepAssertionType] = []
    private(set) var createdIDs: [UInt32] = []
    private(set) var released: [UInt32] = []
    private var nextID: UInt32 = 1

    func createAssertion(type: SleepAssertionType, reason: String) -> UInt32? {
        createdTypes.append(type)
        let id = nextID
        nextID += 1
        createdIDs.append(id)
        return id
    }

    func releaseAssertion(_ id: UInt32) {
        released.append(id)
    }
}
