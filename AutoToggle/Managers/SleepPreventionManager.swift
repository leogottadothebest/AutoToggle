import Foundation
import Observation
import IOKit
@preconcurrency import IOKit.pwr_mgt

/// 防睡眠断言类型
enum SleepAssertionType: Sendable {
    /// 防止系统闲置休眠（显示器仍可关闭）
    case systemSleep
    /// 防止显示器关闭（隐含防止闲置休眠）
    case displaySleep
}

/// 电源断言提供者（可注入，便于单元测试）
protocol PowerAssertionProviding: Sendable {
    /// 创建断言，返回断言 ID；失败返回 nil
    func createAssertion(type: SleepAssertionType, reason: String) -> UInt32?
    /// 释放断言
    func releaseAssertion(_ id: UInt32)
}

/// 真实实现：包装 IOPMAssertionCreateWithName / IOPMAssertionRelease
struct IOPMAssertionProvider: PowerAssertionProviding {
    func createAssertion(type: SleepAssertionType, reason: String) -> UInt32? {
        let assertionType: CFString
        switch type {
        case .systemSleep: assertionType = kIOPMAssertionTypeNoIdleSleep as CFString
        case .displaySleep: assertionType = kIOPMAssertionTypeNoDisplaySleep as CFString
        }

        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        return result == kIOReturnSuccess ? assertionID : nil
    }

    func releaseAssertion(_ id: UInt32) {
        IOPMAssertionRelease(id)
    }
}

/// 防睡眠管理器
/// 分别持有「防止系统休眠」与「防止显示器关闭」两个电源断言，跨启动持久化。
@MainActor
@Observable
final class SleepPreventionManager {
    private let assertionProvider: any PowerAssertionProviding
    private weak var logManager: LogManager?

    /// 是否防止系统休眠
    private(set) var isPreventingSystemSleep: Bool
    /// 是否防止显示器关闭
    private(set) var isPreventingDisplaySleep: Bool

    /// 系统休眠断言 ID
    private var systemSleepAssertionID: UInt32?
    /// 显示器断言 ID
    private var displaySleepAssertionID: UInt32?

    private static let systemSleepKey = "preventSystemSleep"
    private static let displaySleepKey = "preventDisplaySleep"

    init(assertionProvider: any PowerAssertionProviding = IOPMAssertionProvider()) {
        self.assertionProvider = assertionProvider

        // 恢复持久化的开启态（跨启动保持）
        let systemEnabled = UserDefaults.standard.bool(forKey: Self.systemSleepKey)
        let displayEnabled = UserDefaults.standard.bool(forKey: Self.displaySleepKey)

        if systemEnabled {
            systemSleepAssertionID = assertionProvider.createAssertion(
                type: .systemSleep,
                reason: "AutoToggle 防止系统休眠"
            )
        }
        if displayEnabled {
            displaySleepAssertionID = assertionProvider.createAssertion(
                type: .displaySleep,
                reason: "AutoToggle 防止显示器休眠"
            )
        }

        isPreventingSystemSleep = systemEnabled
        isPreventingDisplaySleep = displayEnabled
    }

    /// 注入日志管理器
    func configure(logManager: LogManager) {
        self.logManager = logManager
    }

    /// 设置「防止系统休眠」开关
    func setSystemSleepPrevention(_ enabled: Bool) {
        guard enabled != isPreventingSystemSleep else { return }
        isPreventingSystemSleep = enabled
        UserDefaults.standard.set(enabled, forKey: Self.systemSleepKey)

        if enabled {
            systemSleepAssertionID = assertionProvider.createAssertion(
                type: .systemSleep,
                reason: "AutoToggle 防止系统休眠"
            )
        } else if let id = systemSleepAssertionID {
            assertionProvider.releaseAssertion(id)
            systemSleepAssertionID = nil
        }

        logManager?.addSystem(message: enabled ? "已开启防系统休眠" : "已关闭防系统休眠", level: .info)
    }

    /// 设置「防止显示器关闭」开关
    func setDisplaySleepPrevention(_ enabled: Bool) {
        guard enabled != isPreventingDisplaySleep else { return }
        isPreventingDisplaySleep = enabled
        UserDefaults.standard.set(enabled, forKey: Self.displaySleepKey)

        if enabled {
            displaySleepAssertionID = assertionProvider.createAssertion(
                type: .displaySleep,
                reason: "AutoToggle 防止显示器休眠"
            )
        } else if let id = displaySleepAssertionID {
            assertionProvider.releaseAssertion(id)
            displaySleepAssertionID = nil
        }

        logManager?.addSystem(message: enabled ? "已开启防显示器关闭" : "已关闭防显示器关闭", level: .info)
    }

    /// 快捷切换「防止系统休眠」（供菜单栏/总览卡片）
    func toggleSystemSleep() {
        setSystemSleepPrevention(!isPreventingSystemSleep)
    }
}
