import Foundation

/// 应用信息快照
/// 用于 UI 展示的不可变数据，不持有 NSRunningApplication 引用
/// 相等性与哈希仅以 bundleID 为准
struct AppInfo: Identifiable, Hashable {
    /// 唯一标识符（等同于 bundleID）
    var id: String { bundleID }

    /// Bundle Identifier（如 "com.apple.Safari"）
    let bundleID: String
    /// 应用显示名称
    let displayName: String
    /// 应用路径（如 "/Applications/Safari.app"）
    let appPath: String?

    init(bundleID: String, displayName: String, appPath: String?) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.appPath = appPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
