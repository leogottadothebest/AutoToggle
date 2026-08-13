import Testing
import Foundation
@testable import AutoToggle

/// 系统级闲置时间提供者的冒烟测试
/// IOKit/CGEventSource 读取系统状态，无需权限；仅断言返回非负且不崩溃。
@Suite
struct SystemIdleProviderTests {
    @Test("IOKit 提供者返回非负闲置时间")
    func iokitReturnsNonNegative() {
        let provider = IOKitSystemIdleProvider()
        #expect(provider.systemIdleTime() >= 0)
    }

    @Test("CGEventSource 提供者返回非负闲置时间")
    func cgEventSourceReturnsNonNegative() {
        let provider = CGEventSourceSystemIdleProvider()
        #expect(provider.systemIdleTime() >= 0)
    }

    @Test("混合提供者返回非负闲置时间")
    func hybridReturnsNonNegative() {
        let provider = HybridSystemIdleProvider()
        #expect(provider.systemIdleTime() >= 0)
    }

    @Test("主源不可用时回退到备用源")
    func fallbackSelection() {
        // 主源 nil（IOKit 无节点）→ 采用兜底值
        #expect(SystemIdleFallback.select(primary: nil, fallback: 42) == 42)
        // 主源为 0（刚有输入）→ 采用主源，不回退
        #expect(SystemIdleFallback.select(primary: 0, fallback: 42) == 0)
        // 主源为正 → 采用主源
        #expect(SystemIdleFallback.select(primary: 7.5, fallback: 42) == 7.5)
    }
}
