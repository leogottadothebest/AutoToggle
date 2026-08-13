import AppKit
import Foundation

/// Bundle 辅助工具
/// 提供 Bundle ID ↔ 应用名称 ↔ 应用路径 的互查功能
enum BundleHelper {
    /// 根据 Bundle ID 查找应用路径
    /// - Parameter bundleID: 应用 Bundle Identifier
    /// - Returns: 应用 .app 路径，若未找到返回 nil
    static func appPath(for bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
    }

    /// 根据应用路径获取 Bundle ID
    /// - Parameter appPath: 应用 .app 路径
    /// - Returns: Bundle Identifier
    static func bundleID(for appPath: String) -> String? {
        guard let bundle = Bundle(path: appPath) else { return nil }
        return bundle.bundleIdentifier
    }

    /// 校验 Bundle ID 是否为合法格式。
    ///
    /// Bundle ID 只能由字母、数字、点和连字符组成，且不以点或连字符开头。
    /// 该校验是防注入的关键：`bundleID` 会被拼入 AppleScript 源码字符串，
    /// 任何引号等特殊字符都必须拒绝，否则可被利用执行任意代码（CWE-94）。
    static func isValidBundleID(_ bundleID: String) -> Bool {
        guard !bundleID.isEmpty, bundleID.count <= 255 else { return false }
        return bundleID.range(of: #"^[A-Za-z0-9][A-Za-z0-9.-]*$"#, options: .regularExpression) != nil
    }

    /// 根据应用路径获取显示名称
    /// - Parameter appPath: 应用 .app 路径
    /// - Returns: 应用显示名称
    static func displayName(for appPath: String) -> String? {
        let url = URL(fileURLWithPath: appPath)
        return NSWorkspace.shared.urlForApplication(toOpen: url)
            .flatMap { Bundle(path: $0.path) }
            .flatMap { $0.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? $0.infoDictionary?["CFBundleDisplayName"] as? String
                ?? $0.infoDictionary?["CFBundleName"] as? String }
    }

    /// 获取所有已安装的应用（按名称排序）
    /// - Returns: 所有应用信息列表
    static func allInstalledApps() -> [AppInfo] {
        let commonDirs = [
            "/Applications",
            "/System/Applications",
            "\(NSHomeDirectory())/Applications",
        ]

        var results: [AppInfo] = []
        let fileManager = FileManager.default

        for dir in commonDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else {
                continue
            }

            for item in contents where item.hasSuffix(".app") {
                let appPath = "\(dir)/\(item)"
                let appName = (item as NSString).deletingPathExtension
                guard let bundleID = bundleID(for: appPath) else { continue }

                let displayName = displayName(for: appPath) ?? appName
                results.append(AppInfo(
                    bundleID: bundleID,
                    displayName: displayName,
                    appPath: appPath
                ))
            }
        }

        return results.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
