import SwiftUI

/// 被管理应用的菜单栏行视图
/// 显示应用图标、名称、闲置状态，支持手动退出和激活操作
struct ManagedAppRow: View {
    /// 应用信息
    let app: AppInfo
    /// 闲置状态（nil 表示未被闲置规则管理）
    let idleState: AppIdleStatus?
    /// 退出应用回调
    let onQuit: () -> Void
    /// 激活应用回调
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 10) {
                // 应用图标
                appIconView

                // 应用名称 + 状态
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // 闲置状态指示
                    if let idleState, idleState.isIdle {
                        Text(String(localized: "row.idleFor \(formatIdleTime(idleState.idleSeconds))"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if let idleState, !idleState.isActive {
                        Text("未在使用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("活跃")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                // 退出按钮
                Button(action: onQuit) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help(Text(String(localized: "row.quitApp \(app.displayName)")))
                .accessibilityLabel(Text(String(localized: "row.quitApp \(app.displayName)")))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 子视图

    /// 应用图标视图
    private var appIconView: some View {
        Group {
            if let icon = AppIconProvider.icon(for: app.bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 辅助方法

    /// 格式化闲置时间
    private func formatIdleTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return String(localized: "time.minutesShort \(minutes)")
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return String(localized: "time.hoursShort \(hours)")
        }
        return String(localized: "time.hoursMinutesShort \(hours) \(remainingMinutes)")
    }
}
