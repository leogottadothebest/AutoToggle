import AppKit
import Foundation

/// 应用图标提供者
/// 从应用 Bundle 中提取应用图标，支持线程安全的缓存
/// 所有 AppKit NSImage 操作限定在 @MainActor 上下文中
@MainActor
enum AppIconProvider {
    /// 图标缓存 [bundleID: NSImage]
    private static var cache: [String: NSImage] = [:]

    /// 获取指定应用的图标
    /// - Parameter bundleID: 应用 Bundle Identifier
    /// - Returns: 应用图标，若获取失败返回 nil
    static func icon(for bundleID: String) -> NSImage? {
        // 优先从缓存获取
        if let cached = cache[bundleID] {
            return cached
        }

        // 查找应用路径
        guard let appPath = BundleHelper.appPath(for: bundleID) else {
            return nil
        }

        // 从 .app Bundle 提取图标
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        cache[bundleID] = icon

        return icon
    }
}
