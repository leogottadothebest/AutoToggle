import Foundation
import Observation
import Sparkle

/// 应用自动更新管理器（Sparkle 2）。
///
/// 封装 `SPUStandardUpdaterController`，让视图层不直接依赖 Sparkle 类型，
/// 与 MenuBarManager 等保持一致的分层与注入方式。
@MainActor
@Observable
final class UpdateManager {
    private let updaterController: SPUStandardUpdaterController

    init() {
        // startingUpdater: true 让 Sparkle 启动即开始按默认周期（每 24h）后台检查更新。
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// 手动触发「检查更新」（设置页「关于」区按钮调用）。
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// 是否自动检查更新（读写 Sparkle 设置，持久化到 UserDefaults）。
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
}
