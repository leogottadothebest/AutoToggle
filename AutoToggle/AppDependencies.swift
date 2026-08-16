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

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: AppRule.self, LogEntry.self, Profile.self)
        } catch {
            // CWE-248：捕获底层错误并写入统一日志，附带可操作提示，
            // 而非 opaque fatalError 让用户无从排查。
            let detail = "AutoToggle 数据存储初始化失败：\(error.localizedDescription)。" +
                         "可在 ~/Library/Application Support/ 下找到 AutoToggle 数据目录，" +
                         "备份后删除其中的 .store 文件以恢复。"
            NSLog("[AppDependencies] %@", detail)
            fatalError(detail)
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
}
