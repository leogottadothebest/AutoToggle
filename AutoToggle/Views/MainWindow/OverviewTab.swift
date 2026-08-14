import SwiftUI

/// 总览 Dashboard 标签页
/// 显示 AutoToggle 运行状态全景，4 张可交互状态卡片 + 活动 + 被管理应用
struct OverviewTab: View {
    @Environment(RuleManager.self) private var ruleManager
    @Environment(AppMonitorManager.self) private var appMonitorManager
    @Environment(ScheduleManager.self) private var scheduleManager
    @Environment(LogManager.self) private var logManager
    @Environment(IdleDetectorManager.self) private var idleDetectorManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(SleepPreventionManager.self) private var sleepPreventionManager

    /// 从父视图传入的 Tab 切换 Binding
    @Binding var selectedTab: MainWindowView.MainTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 状态卡片行（3 张卡片）
                statusCardsGrid

                // 下次触发
                if scheduleManager.nextTriggerTime != nil {
                    nextTriggerCard
                }

                // 最近活动
                recentActivitySection

                // 运行中的被管理应用
                managedAppsSection
            }
            .padding(20)
        }
        .background(.windowBackground)
    }

    // MARK: - 状态卡片网格

    private var statusCardsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            StatusCard(
                title: String(localized: "card.activeRules"),
                value: "\(ruleManager.enabledRules.count)",
                systemImage: "list.bullet.clipboard",
                color: .blue
            ) {
                selectedTab = .apps
            }

            StatusCard(
                title: String(localized: "card.managedApps"),
                value: "\(ruleManager.managedBundleIDs().count)",
                systemImage: "app.badge",
                color: .purple
            ) {
                selectedTab = .apps
            }

            StatusCard(
                title: String(localized: "card.activeProfile"),
                value: profileManager.activeProfile?.name ?? String(localized: "profile.default"),
                systemImage: "square.grid.2x2",
                color: .indigo
            ) {
                selectedTab = .apps
            }
            .contextMenu {
                ForEach(profileManager.profiles, id: \.id) { profile in
                    Button {
                        profileManager.activateProfile(profile)
                    } label: {
                        Text(profile.name)
                        if profile.isActive {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            StatusCard(
                title: "防睡眠",
                value: sleepPreventionManager.isPreventingSystemSleep ? "已开启" : "已关闭",
                systemImage: sleepPreventionManager.isPreventingSystemSleep ? "moon.zzz.fill" : "moon.zzz",
                color: sleepPreventionManager.isPreventingSystemSleep ? .green : .secondary
            ) {
                sleepPreventionManager.toggleSystemSleep()
            }
        }
    }

    // MARK: - 下次触发卡片

    private var nextTriggerCard: some View {
        HStack {
            Image(systemName: "clock.badge")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "overview.nextTrigger"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let nextTrigger = scheduleManager.nextTriggerTime {
                    Text(formatFullTime(nextTrigger))
                        .font(.headline)
                }
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }

    // MARK: - 最近活动

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "overview.recentActivity"))
                .font(.headline)

            let recentLogs = logManager.entries(for: .activity, limit: 5)

            if recentLogs.isEmpty {
                Text(String(localized: "overview.noActivity"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentLogs.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.caption)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.message)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(formatRelativeTime(entry.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)

                        if index < recentLogs.count - 1 {
                            Divider()
                                .padding(.leading, 28)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - 被管理应用

    private var managedAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "overview.managedApps"))
                .font(.headline)

            let managedBundleIDs = ruleManager.managedBundleIDs()
            let runningManaged = AppSortHelper.sorted(
                appMonitorManager.runningApps.filter {
                    managedBundleIDs.contains($0.bundleID)
                }
            )

            if runningManaged.isEmpty {
                Text(String(localized: "overview.noManagedAppsRunning"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(runningManaged.enumerated()), id: \.element.id) { index, app in
                        HStack(spacing: 10) {
                            if let icon = AppIconProvider.icon(for: app.bundleID) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }

                            Text(app.displayName)
                                .font(.body)

                            Spacer()

                            if let idleState = idleDetectorManager.idleState(for: app.bundleID),
                               idleState.isIdle {
                                Label(String(localized: "status.idle"),
                                      systemImage: "moon.zzz")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Label(String(localized: "status.active"),
                                      systemImage: "circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        if index < runningManaged.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - 辅助方法

    private func formatFullTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return String(localized: "time.justNow")
        } else if interval < 3600 {
            return String(localized: "time.minutesAgo \(Int(interval / 60))")
        } else if interval < 86400 {
            return String(localized: "time.hoursAgo \(Int(interval / 3600))")
        } else {
            return formatFullTime(date)
        }
    }
}

// MARK: - 状态卡片组件

struct StatusCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    var action: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(color)

                Spacer()

                if action != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .opacity(isHovering ? 1 : 0)
                }
            }

            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(isHovering ? 0.08 : 0.03), radius: isHovering ? 8 : 4, y: isHovering ? 3 : 1)
        .scaleEffect(isHovering && action != nil ? 1.02 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            action?()
        }
    }
}
