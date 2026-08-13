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
}
