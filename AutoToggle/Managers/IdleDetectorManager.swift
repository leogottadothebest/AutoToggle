import Foundation
import AppKit

/// 应用闲置状态
struct AppIdleStatus {
    /// 最后活跃时间
    let lastActiveTime: Date
    /// 是否处于闲置状态
    var isIdle: Bool { idleSeconds >= idleThreshold }
    /// 是否处于活跃状态（当前拥有焦点）
    let isActive: Bool
    /// 闲置秒数
    var idleSeconds: TimeInterval { Date().timeIntervalSince(lastActiveTime) }
    /// 闲置阈值（秒）
    let idleThreshold: TimeInterval

    init(lastActiveTime: Date, isActive: Bool = true, idleThreshold: TimeInterval = 600) {
        self.lastActiveTime = lastActiveTime
        self.isActive = isActive
        self.idleThreshold = idleThreshold
    }
}

/// 闲置检测管理器
/// 检测应用级别和系统级别的闲置状态，判断假闲置场景，触发自动退出/隐藏动作
@MainActor
@Observable
final class IdleDetectorManager {
    // MARK: - 私有属性

    /// 检测 Timer（每 30 秒触发一次）
    private var timer: Timer?

    /// 每个应用的最后活跃时间 [bundleID: lastActiveTime]
    private var appLastActiveTime: [String: Date] = [:]

    /// 规则管理器引用
    private weak var ruleManager: RuleManager?

    /// 应用操作管理器引用
    private weak var appActionManager: AppActionManager?

    /// 日志管理器引用
    private weak var logManager: LogManager?

    /// 已触发的闲置规则记录，键为「应用 + 规则」
    /// 一旦触发即锁定，直到应用再次活跃（markAppActive）才清除，防止同一闲置周期内反复触发
    private var lastTriggered: [RuleTriggerKey: Date] = [:]

    /// 系统级闲置时间提供者（IOKit + CGEventSource 兜底，无需权限）
    private var systemIdleProvider: any SystemIdleProviding = HybridSystemIdleProvider()

    /// 焦点应用提供者（辅助功能授权时更精确，未授权回退 NSWorkspace）
    private var focusedAppProvider: any FocusedAppProviding = PermissionAwareFocusedAppProvider()

    /// 触发记录键：应用 Bundle ID + 规则 ID
    private struct RuleTriggerKey: Hashable {
        let bundleID: String
        let ruleID: UUID
    }

    /// 假闲置保护的应用：目标应用本身是音频播放或会议应用时，不因「闲置」而误关
    private static let protectedBundleIDs: Set<String> = [
        // 音频播放
        "com.apple.Music", "com.spotify.client", "com.apple.QuickTimePlayerX",
        "com.videolan.vlc", "com.tencent.QQMusicMac", "com.netease.163music",
        // 会议
        "us.zoom.xos", "com.microsoft.teams", "com.tencent.meeting",
        "com.alibaba.DingTalkMac", "com.bytedance.lark",
    ]

    // MARK: - 公开方法

    /// 启动闲置检测
    func startMonitoring() {
        stopMonitoring()

        // 初始化所有被管理应用的活跃时间
        if let ruleManager {
            for bundleID in ruleManager.managedBundleIDs() {
                if appLastActiveTime[bundleID] == nil {
                    appLastActiveTime[bundleID] = Date()
                }
            }
        }

        // 每 30 秒检查一次
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkIdleState()
            }
        }
    }

    /// 停止闲置检测
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// 依赖注入
    func configure(
        ruleManager: RuleManager,
        appActionManager: AppActionManager,
        logManager: LogManager,
        systemIdleProvider: (any SystemIdleProviding)? = nil,
        focusedAppProvider: (any FocusedAppProviding)? = nil
    ) {
        self.ruleManager = ruleManager
        self.appActionManager = appActionManager
        self.logManager = logManager
        if let systemIdleProvider { self.systemIdleProvider = systemIdleProvider }
        if let focusedAppProvider { self.focusedAppProvider = focusedAppProvider }
    }

    /// 标记应用为活跃（在应用切换或应用启动时调用），重置其闲置基线。
    /// 应用启动（含定时/后台启动）时若不重置，陈旧的活跃时间会让闲置规则立即误触发。
    func markAppActive(_ bundleID: String) {
        appLastActiveTime[bundleID] = Date()
        // 应用被重新激活/启动，清除该应用所有规则的触发记录，进入新的活跃周期
        lastTriggered = lastTriggered.filter { $0.key.bundleID != bundleID }
    }

    /// 获取指定应用的闲置状态（无闲置规则时返回 nil）
    func idleState(for bundleID: String) -> AppIdleStatus? {
        guard let ruleManager else { return nil }

        let idleRules = ruleManager.enabledRules.filter {
            $0.appBundleID == bundleID && $0.ruleType.isIdle
        }
        guard let rule = idleRules.first, let idleTrigger = rule.idleTrigger else {
            return nil
        }

        let threshold = TimeInterval(idleTrigger.idleMinutes * 60)
        let isActive = focusedAppProvider.focusedAppBundleID() == bundleID

        switch idleTrigger.scope {
        case .app:
            guard let lastActive = appLastActiveTime[bundleID] else { return nil }
            return AppIdleStatus(lastActiveTime: lastActive, isActive: isActive, idleThreshold: threshold)
        case .system:
            // 系统闲置：以系统全局闲置时间反推「最后活跃时间」，使 isIdle 语义与触发一致
            let idle = systemIdleProvider.systemIdleTime()
            return AppIdleStatus(
                lastActiveTime: Date().addingTimeInterval(-idle),
                isActive: isActive,
                idleThreshold: threshold
            )
        }
    }

    /// 判断目标应用是否处于假闲置状态（仅当目标应用本身是音频/会议应用时保护）
    func isFakeIdle(bundleID: String) -> Bool {
        Self.protectedBundleIDs.contains(bundleID)
    }

    /// 判断系统是否"并非真正闲置"：任意音频/会议应用在运行即视为用户可能在场。
    /// 仅用于 .system 范围的闲置规则，避免全局音频误拦截 .app 范围规则（MED-4）。
    func isSystemBusy() -> Bool {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return !running.isDisjoint(with: Self.protectedBundleIDs)
    }

    // MARK: - 内部方法

    /// 检查闲置状态并触发对应动作
    private func checkIdleState() {
        // 检查暂停状态
        guard !isPaused() else { return }

        guard let ruleManager, let appActionManager else { return }

        let now = Date()
        let idleRules = ruleManager.enabledRules.filter { $0.ruleType.isIdle }

        // 仅当存在系统闲置规则时才读取系统闲置时间（避免为纯应用规则做无谓的 IOKit 读取）
        let hasSystemScope = idleRules.contains { $0.idleTrigger?.scope == .system }
        let systemIdle = hasSystemScope ? systemIdleProvider.systemIdleTime() : 0

        // 补齐启动后才新增应用的活跃记录，避免其 .app 闲置规则一直无法生效
        for bundleID in ruleManager.managedBundleIDs() where appLastActiveTime[bundleID] == nil {
            appLastActiveTime[bundleID] = now
        }

        // 检查每个闲置规则
        for rule in idleRules {
            guard let idleTrigger = rule.idleTrigger else { continue }

            // HIGH-1 修复：.app 范围下，若目标应用当前在前台（用户正在使用），
            // 刷新其活跃时间并跳过，避免连续使用超过阈值被误关。
            if idleTrigger.scope == .app,
               focusedAppProvider.focusedAppBundleID() == rule.appBundleID {
                appLastActiveTime[rule.appBundleID] = now
                continue
            }

            let threshold = TimeInterval(idleTrigger.idleMinutes * 60)
            let key = RuleTriggerKey(bundleID: rule.appBundleID, ruleID: rule.id)

            // MED-4 修复：.app 仅保护目标应用自身；.system 检测任意音频/会议活动
            let fakeIdle: Bool
            switch idleTrigger.scope {
            case .app:
                fakeIdle = isFakeIdle(bundleID: rule.appBundleID)
            case .system:
                fakeIdle = isSystemBusy()
            }

            let shouldFire = IdleDecisionEngine.decideTrigger(
                scope: idleTrigger.scope,
                appLastActive: appLastActiveTime[rule.appBundleID],
                systemIdle: systemIdle,
                now: now,
                thresholdSeconds: threshold,
                isFakeIdle: fakeIdle,
                alreadyTriggered: lastTriggered[key] != nil,
                isAppRunning: appActionManager.isAppRunning(bundleID: rule.appBundleID)
            )

            guard shouldFire else { continue }

            lastTriggered[key] = now
            executeIdleAction(rule: rule, actionManager: appActionManager)
        }
    }

    /// 执行闲置动作
    private func executeIdleAction(rule: AppRule, actionManager: AppActionManager) {
        let action: String
        switch rule.ruleType {
        case .idleQuit:
            action = String(localized: "ruleType.idleQuit")
            actionManager.terminateApp(bundleID: rule.appBundleID, strategy: rule.quitStrategy)
        case .idleHide:
            action = String(localized: "ruleType.idleHide")
            actionManager.hideApp(bundleID: rule.appBundleID)
        default:
            return
        }

        logManager?.addActivity(
            message: String(localized: "log.action \(action) \(rule.appName)"),
            relatedAppName: rule.appName
        )
    }

    /// 检查是否处于暂停状态
    private func isPaused() -> Bool {
        UserDefaults.standard.bool(forKey: "isPaused")
    }
}
