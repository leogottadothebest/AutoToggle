import Testing
import Foundation
@testable import AutoToggle

/// 闲置触发条件的编码/解码测试（含向后兼容）
@Suite
struct IdleTriggerTests {
    @Test("旧数据缺少 scope 字段时解码为应用闲置")
    func legacyPayloadDecodesToAppScope() throws {
        let legacy = #"{"idleMinutes": 15}"#.data(using: .utf8)!
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: legacy)
        #expect(trigger.idleMinutes == 15)
        #expect(trigger.scope == .app)
    }

    @Test("新数据含 scope 字段时正确解码")
    func newPayloadDecodesScope() throws {
        let json = #"{"idleMinutes": 5, "scope": "system"}"#.data(using: .utf8)!
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: json)
        #expect(trigger.idleMinutes == 5)
        #expect(trigger.scope == .system)
    }

    @Test("编码再解码保持字段一致")
    func roundTripPreservesFields() throws {
        let original = IdleTrigger(idleMinutes: 30, scope: .system)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IdleTrigger.self, from: data)
        #expect(decoded == original)
    }

    @Test("scope 原始值稳定")
    func scopeRawValuesAreStable() {
        #expect(IdleScope.app.rawValue == "app")
        #expect(IdleScope.system.rawValue == "system")
    }

    // MARK: - 畸形/越界 JSON 防护（解码层钳制）

    @Test("idleMinutes 超过上限被钳制到 1440")
    func oversizedIdleMinutesClampsToUpperBound() throws {
        let json = #"{"idleMinutes": 9999}"#.data(using: .utf8)!
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: json)
        #expect(trigger.idleMinutes == 1440)
    }

    @Test("负数 idleMinutes 被钳制到 1")
    func negativeIdleMinutesClampsToLowerBound() throws {
        let json = #"{"idleMinutes": -5}"#.data(using: .utf8)!
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: json)
        #expect(trigger.idleMinutes == 1)
    }

    @Test("零值 idleMinutes 被钳制到 1")
    func zeroIdleMinutesClampsToLowerBound() throws {
        let json = #"{"idleMinutes": 0}"#.data(using: .utf8)!
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: json)
        #expect(trigger.idleMinutes == 1)
    }

    @Test("缺少 idleMinutes 字段回退默认 10")
    func missingIdleMinutesFallsBackToDefault() throws {
        let json = #"{}"#.data(using: .utf8)!
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: json)
        #expect(trigger.idleMinutes == 10)
        #expect(trigger.scope == .app)
    }

    @Test("idleMinutes 类型错误（字符串）抛解码错误")
    func wrongTypedIdleMinutesThrows() {
        let json = #"{"idleMinutes": "abc"}"#.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(IdleTrigger.self, from: json)
        }
    }
}
