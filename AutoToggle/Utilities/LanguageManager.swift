import Foundation

/// 语言管理器
/// 把设置里的 `appLanguage` 同步到 `AppleLanguages`，使 SwiftUI `Text` / `String(localized:)`
/// 按所选语言解析；「跟随系统」时清除覆盖、回退到系统首选语言。
/// 语言切换需要重启应用才完全生效（见 SettingsTab 的「需要重启」提示）。
enum LanguageManager {
    /// 把语言码写入 `AppleLanguages`（下次启动生效；当前进程内已创建的视图需重建）
    /// - Parameter code: "zh-Hans" / "en" / "system"（其它值按跟随系统处理）
    static func apply(_ code: String) {
        switch code {
        case "zh-Hans":
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        case "en":
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        default:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    /// 读取持久化的 `appLanguage` 并应用。
    /// 须在**任何本地化查找之前**调用（应用启动最早时机），否则已缓存的首选语言不会更新。
    static func applyStoredLanguage() {
        apply(UserDefaults.standard.string(forKey: "appLanguage") ?? "system")
    }
}
