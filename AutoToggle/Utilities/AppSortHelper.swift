import Foundation

/// 应用名称排序辅助工具
/// 依据应用当前界面语言选择排序规则：中文界面按拼音、英文界面按字母。
/// 同时提供「拼音首字母」分组索引，供应用选择器右侧字母表导航使用。
enum AppSortHelper {

    /// 应用列表排序方向：true = 从大到小（Z→A / 反拼音），false = 从小到大（A→Z）
    static let sortDescending = false

    /// 当前生效的界面语言代码（"zh-Hans" / "en"）。
    /// 读取 SettingsTab 持久化的 `appLanguage`；"system" 时回退到系统首选语言。
    static var effectiveLanguage: String {
        switch UserDefaults.standard.string(forKey: "appLanguage") {
        case "zh-Hans":
            return "zh-Hans"
        case "en":
            return "en"
        default:
            let preferred = Locale.preferredLanguages.first ?? ""
            return preferred.lowercased().hasPrefix("zh") ? "zh-Hans" : "en"
        }
    }

    /// 排序所用的 Locale（中文界面用 zh，英文界面用 en）
    static var sortLocale: Locale {
        effectiveLanguage == "zh-Hans"
            ? Locale(identifier: "zh_Hans")
            : Locale(identifier: "en_US")
    }

    /// 本地化比较两个名称，返回 ComparisonResult。
    /// 忽略大小写、声调、全半角差异；中文界面下按拼音排序。
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(
            rhs,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            range: nil,
            locale: sortLocale
        )
    }

    /// 按显示名排序应用列表，方向由 `sortDescending` 决定。
    static func sorted(_ apps: [AppInfo]) -> [AppInfo] {
        apps.sorted { lhs, rhs in
            let result = compare(lhs.displayName, rhs.displayName)
            return sortDescending ? result == .orderedDescending : result == .orderedAscending
        }
    }

    /// 分组字母间的排序：`#` 组在降序时排最后、升序时排最前，其余按方向排列。
    static func isOrderedBefore(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return false }
        if lhs == "#" { return !sortDescending }
        if rhs == "#" { return sortDescending }
        return sortDescending ? lhs > rhs : lhs < rhs
    }

    /// 应用名的分组索引字母：拉丁字母取首字母大写，中文取拼音首字母，其它归入 "#"。
    static func indexLetter(for name: String) -> String {
        guard let first = name.first else { return "#" }
        let firstString = String(first)

        // 已是拉丁字母：直接取其大写
        if firstString.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
            return firstString.uppercased()
        }

        // 中文等其它字符：先转拼音，再取首字母
        let latin = name.applyingTransform(.toLatin, reverse: false) ?? name
        let stripped = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        guard let pinyinFirst = stripped.first else { return "#" }
        let pinyinLetter = String(pinyinFirst).uppercased()
        return pinyinLetter.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil ? pinyinLetter : "#"
    }
}
