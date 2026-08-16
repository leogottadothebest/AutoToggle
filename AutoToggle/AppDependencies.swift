import SwiftUI
import SwiftData
import Foundation

/// 应用依赖集合
/// 集中创建并装配所有管理器，统一注入给 AppDelegate 和视图环境，
/// 避免在 AutoToggleApp / AppDelegate 之间散落 9 个可选引用和强制解包
@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let menuBarManager = MenuBarManager()
    let appearanceManager = AppearanceManager()
    let permissionManager = PermissionManager()
    let appMonitorManager = AppMonitorManager()
    let appActionManager: AppActionManager
    let ruleManager: RuleManager
    let logManager: LogManager
    let scheduleManager: ScheduleManager
    let idleDetectorManager: IdleDetectorManager
    let profileManager: ProfileManager
    let sleepPreventionManager: SleepPreventionManager
    let updateManager = UpdateManager()
    let diagnosticsManager = DiagnosticsManager()
    let globalHotkeyManager = GlobalHotkeyManager()

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: AppSchema.schema)
        } catch {
            // 数据 store 损坏/无法打开：备份后重建空库，避免硬崩。
            // 损坏数据保留在 .corrupt-<时间戳> 备份中，用户不会丢数据。
            let detail = "AutoToggle 数据存储初始化失败：\(error.localizedDescription)"
            Log.persistence.error("\(detail, privacy: .public)")
            guard let recovered = Self.recoverModelContainer() else {
                // 最终兜底：连备份重建都失败才硬崩，附可操作提示。
                fatalError("\(detail)。可在 ~/Library/Application Support/ 下找到 AutoToggle 数据目录，备份后删除其中的 .store 文件以恢复。")
            }
            container = recovered
            Log.persistence.notice("已备份损坏的数据存储并重建空库")
        }
        modelContainer = container

        let action = AppActionManager()
        let rules = RuleManager(modelContainer: container)
        let logs = LogManager(modelContainer: container)
        let sched = ScheduleManager(ruleManager: rules, appActionManager: action, logManager: logs)
        let idle = IdleDetectorManager()
        idle.configure(ruleManager: rules, appActionManager: action, logManager: logs)
        let profiles = ProfileManager(modelContainer: container, ruleManager: rules)
        let sleep = SleepPreventionManager()
        sleep.configure(logManager: logs)

        action.configure(logManager: logs)
        rules.configure(logManager: logs)
        rules.configure(profileManager: profiles)
        diagnosticsManager.configure(permissionManager: permissionManager, logManager: logs, ruleManager: rules)

        appMonitorManager.onFrontmostAppChanged = { [weak idle] bundleID in
            idle?.markAppActive(bundleID)
        }

        // 应用启动（含定时启动 / 后台启动）时重置闲置基线：
        // 否则 appLastActiveTime 停留在陈旧时间，应用一启动，下一次闲置检测
        // （30s tick）就误判为「已闲置超过阈值」而立即退出（如百度网盘定时启动后几十秒被闲置退出）。
        appMonitorManager.onAppLaunched = { [weak idle] bundleID in
            idle?.markAppActive(bundleID)
        }

        logs.addSystem(message: String(localized: "AutoToggle 启动完成"), level: .info)
        logs.enforceRetentionPolicy()

        appActionManager = action
        ruleManager = rules
        logManager = logs
        scheduleManager = sched
        idleDetectorManager = idle
        profileManager = profiles
        sleepPreventionManager = sleep
    }

    // MARK: - 数据恢复

    /// 备份损坏的 SwiftData store（含 -wal/-shm 伴生文件）后重建空库。
    /// 返回重建成功的 ModelContainer；任一步失败返回 nil（调用方兜底 fatalError）。
    private static func recoverModelContainer() -> ModelContainer? {
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let base = supportDir.appendingPathComponent("default.store")
        let candidates = [
            base,
            URL(fileURLWithPath: base.path + "-wal"),
            URL(fileURLWithPath: base.path + "-shm"),
        ]
        let timestamp = Int(Date().timeIntervalSince1970)
        do {
            for url in candidates where fileManager.fileExists(atPath: url.path) {
                let backup = URL(fileURLWithPath: url.path + ".corrupt-\(timestamp)")
                try fileManager.moveItem(at: url, to: backup)
            }
            return try ModelContainer(for: AppSchema.schema)
        } catch {
            Log.persistence.error("恢复数据存储失败: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
