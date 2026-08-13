import Testing
import Foundation
@testable import AutoToggle

/// AutoToggle 安全与逻辑单元测试
/// 覆盖 Bundle ID 校验（防注入）、闲置决策引擎、向后兼容解码
@Suite
struct AutoToggleTests {

    // MARK: - Bundle ID 校验（防 AppleScript 注入，CWE-94）

    @Test("合法 Bundle ID 通过校验")
    func validBundleIDs() {
        #expect(BundleHelper.isValidBundleID("com.apple.Safari"))
        #expect(BundleHelper.isValidBundleID("com.tencent.meeting"))
        #expect(BundleHelper.isValidBundleID("com.bytedance.lark"))
        #expect(BundleHelper.isValidBundleID("a"))
        #expect(BundleHelper.isValidBundleID("com.example.app-1.2.3"))
    }

    @Test("非法 Bundle ID 被拒绝（注入载荷）")
    func invalidBundleIDs() {
        #expect(!BundleHelper.isValidBundleID(""))
        #expect(!BundleHelper.isValidBundleID("com.example\"; do shell script \"touch /tmp/pwned\" --"))
        #expect(!BundleHelper.isValidBundleID("com.example with space"))
        #expect(!BundleHelper.isValidBundleID(".com.example"))   // 以点开头
        #expect(!BundleHelper.isValidBundleID("-com.example"))   // 以连字符开头
        #expect(!BundleHelper.isValidBundleID("com.example\nquit"))
        #expect(!BundleHelper.isValidBundleID("com.example'"))
    }

    // MARK: - 闲置决策引擎（纯函数）

    @Test("闲置达到阈值且无假闲置则触发")
    func idleTriggerFires() {
        let fires = IdleDecisionEngine.decideTrigger(
            scope: .app,
            appLastActive: Date(timeIntervalSince1970: 0),
            systemIdle: 0,
            now: Date(timeIntervalSince1970: 600),
            thresholdSeconds: 600,
            isFakeIdle: false,
            alreadyTriggered: false,
            isAppRunning: true
        )
        #expect(fires)
    }

    @Test("假闲置（音频/会议）不触发")
    func fakeIdleDoesNotFire() {
        let fires = IdleDecisionEngine.decideTrigger(
            scope: .app,
            appLastActive: Date(timeIntervalSince1970: 0),
            systemIdle: 0,
            now: Date(timeIntervalSince1970: 600),
            thresholdSeconds: 600,
            isFakeIdle: true,
            alreadyTriggered: false,
            isAppRunning: true
        )
        #expect(!fires)
    }

    @Test("已触发过则不重复触发")
    func alreadyTriggeredDoesNotFire() {
        let fires = IdleDecisionEngine.decideTrigger(
            scope: .app,
            appLastActive: Date(timeIntervalSince1970: 0),
            systemIdle: 0,
            now: Date(timeIntervalSince1970: 600),
            thresholdSeconds: 600,
            isFakeIdle: false,
            alreadyTriggered: true,
            isAppRunning: true
        )
        #expect(!fires)
    }

    @Test("应用未运行则不触发")
    func appNotRunningDoesNotFire() {
        let fires = IdleDecisionEngine.decideTrigger(
            scope: .app,
            appLastActive: Date(timeIntervalSince1970: 0),
            systemIdle: 0,
            now: Date(timeIntervalSince1970: 600),
            thresholdSeconds: 600,
            isFakeIdle: false,
            alreadyTriggered: false,
            isAppRunning: false
        )
        #expect(!fires)
    }

    @Test("应用闲置范围缺少活跃记录则不触发")
    func appScopeMissingLastActiveDoesNotFire() {
        let fires = IdleDecisionEngine.decideTrigger(
            scope: .app,
            appLastActive: nil,
            systemIdle: 99_999,
            now: Date(timeIntervalSince1970: 600),
            thresholdSeconds: 600,
            isFakeIdle: false,
            alreadyTriggered: false,
            isAppRunning: true
        )
        #expect(!fires)
    }

    @Test("系统闲置范围按全局闲置时间判断")
    func systemScopeUsesSystemIdle() {
        let fires = IdleDecisionEngine.decideTrigger(
            scope: .system,
            appLastActive: nil,
            systemIdle: 700,
            now: Date(timeIntervalSince1970: 600),
            thresholdSeconds: 600,
            isFakeIdle: false,
            alreadyTriggered: false,
            isAppRunning: true
        )
        #expect(fires)
    }

    // MARK: - IdleTrigger 向后兼容解码

    @Test("旧数据无 scope 字段时默认 app")
    func idleTriggerBackwardCompatibleDecoding() throws {
        let json = Data(#"{"idleMinutes": 15}"#.utf8)
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: json)
        #expect(trigger.scope == .app)
        #expect(trigger.idleMinutes == 15)
    }

    @Test("新数据含 scope 字段时正确解码")
    func idleTriggerDecodesScope() throws {
        let json = Data(#"{"idleMinutes": 30, "scope": "system"}"#.utf8)
        let trigger = try JSONDecoder().decode(IdleTrigger.self, from: json)
        #expect(trigger.scope == .system)
        #expect(trigger.idleMinutes == 30)
    }
}
