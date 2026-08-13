import Testing
import Foundation
@testable import AutoToggle

/// IdleDetectorManager 的假闲置保护语义测试
@Suite
struct IdleDetectorManagerTests {
    @Test
    @MainActor
    func 假闲置仅保护音频与会议应用自身() {
        let manager = IdleDetectorManager()

        // 音频/会议应用本身受保护，不因「闲置」被误关
        #expect(manager.isFakeIdle(bundleID: "com.spotify.client"))
        #expect(manager.isFakeIdle(bundleID: "com.apple.Music"))
        #expect(manager.isFakeIdle(bundleID: "us.zoom.xos"))
        #expect(manager.isFakeIdle(bundleID: "com.microsoft.teams"))

        // 无关应用不再受全局音频影响（修复：此前 isAudioPlaying 全局拦截所有规则）
        #expect(!manager.isFakeIdle(bundleID: "com.apple.Safari"))
        #expect(!manager.isFakeIdle(bundleID: "com.microsoft.VSCode"))
    }
}
