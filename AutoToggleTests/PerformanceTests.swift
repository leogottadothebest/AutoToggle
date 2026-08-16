import XCTest
@testable import AutoToggle

/// 性能基线测试：防止闲置检测与决策引擎出现 O(n) 退化。
/// 使用 XCTest 的 measure（Swift Testing 无对应 API），不设 baseline，仅测量不 fail。
final class PerformanceTests: XCTestCase {
    func testIOKitIdleProviderPerformance() {
        let provider = IOKitSystemIdleProvider()
        measure {
            _ = provider.systemIdleTime()
        }
    }

    func testCGEventSourceIdleProviderPerformance() {
        let provider = CGEventSourceSystemIdleProvider()
        measure {
            _ = provider.systemIdleTime()
        }
    }

    func testHybridIdleProviderPerformance() {
        let provider = HybridSystemIdleProvider()
        measure {
            _ = provider.systemIdleTime()
        }
    }

    func testIdleDecisionEnginePerformance() {
        measure {
            for _ in 0..<100 {
                _ = IdleDecisionEngine.shouldTrigger(IdleDecisionInput(
                    idleSeconds: 300,
                    thresholdSeconds: 60,
                    isFakeIdle: false,
                    alreadyTriggered: false,
                    isAppRunning: true
                ))
            }
        }
    }
}
