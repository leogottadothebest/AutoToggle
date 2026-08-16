import AppKit
import Foundation
import UniformTypeIdentifiers

/// 诊断导出管理器：一键生成本地诊断报告供用户附加到 Issue。
/// 仅本地写入、不自动上传，贴合「隐私优先」定位。
@MainActor
@Observable
final class DiagnosticsManager {
    private weak var permissionManager: PermissionManager?
    private weak var logManager: LogManager?
    private weak var ruleManager: RuleManager?

    func configure(permissionManager: PermissionManager, logManager: LogManager, ruleManager: RuleManager) {
        self.permissionManager = permissionManager
        self.logManager = logManager
        self.ruleManager = ruleManager
    }

    /// 弹出保存面板，把诊断报告导出为 .txt
    func exportDiagnostics() {
        let report = buildReport()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "AutoToggle-诊断报告-\(Self.timestampString()).txt"
        panel.begin { [report] response in
            guard response == .OK, let url = panel.url else { return }
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// 在 Finder 中打开崩溃日志目录（~/Library/Logs/DiagnosticReports），
    /// 供用户本地查看 .ips 崩溃报告——隐私优先，不自动上传。
    func openCrashLogsDirectory() {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/DiagnosticReports", isDirectory: true)
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - 报告内容

    private func buildReport() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let granted = permissionManager?.accessibilityGranted ?? false
        let ruleCount = ruleManager?.allRules.count ?? 0
        let logs = logManager?.recentEntries(limit: 50) ?? []

        var lines: [String] = []
        lines.append("AutoToggle 诊断报告")
        lines.append("==================")
        lines.append("版本: \(version) (\(build))")
        lines.append("macOS: \(os)")
        lines.append("辅助功能权限: \(granted ? "已授权" : "未授权")")
        lines.append("规则数量: \(ruleCount)")
        lines.append("")
        lines.append("最近日志:")
        if logs.isEmpty {
            lines.append("（无日志）")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            for entry in logs {
                let time = formatter.string(from: entry.timestamp)
                let category = entry.category == .activity ? "活动" : "系统"
                lines.append("[\(time)] [\(category)] [\(entry.level.rawValue)] \(entry.message)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
