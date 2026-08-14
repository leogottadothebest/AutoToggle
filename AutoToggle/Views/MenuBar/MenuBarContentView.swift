import SwiftUI

/// 菜单栏下拉面板主视图
/// 显示被管理应用的运行状态、规则信息和操作入口
struct MenuBarContentView: View {
    /// 打开主窗口的回调（由 MenuBarController 注入，避免依赖 NSApp.delegate）
    let onOpenMainWindow: () -> Void

    // MARK: - Environment

    @Environment(MenuBarManager.self) private var menuBarManager
    @Environment(AppMonitorManager.self) private var appMonitorManager
    @Environment(RuleManager.self) private var ruleManager
    @Environment(ScheduleManager.self) private var scheduleManager
    @Environment(IdleDetectorManager.self) private var idleDetectorManager
    @Environment(AppActionManager.self) private var appActionManager
    @Environment(ProfileManager.self) private var profileManager
    @Environment(SleepPreventionManager.self) private var sleepPreventionManager

    // MARK: - State

    /// 是否已展示过首次使用引导
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// 首次启动时显示权限引导
    @State private var showPermissionGuide = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            headerView

            Divider()

            // 定时任务（与被管理应用同等地位，含禁用的任务）
            if !upcomingTriggers.isEmpty {
                scheduledTasksSection
                Divider()
            }

            // 被管理应用列表
            if managedApps.isEmpty {
                emptyStateView
            } else {
                managedAppsSection
            }
        }
        .frame(width: 300)
        .onAppear {
            updateStats()

            // 首次启动显示权限引导
            if !hasCompletedOnboarding {
                showPermissionGuide = true
            }
        }
        .sheet(isPresented: $showPermissionGuide) {
            PermissionGrantView {
                hasCompletedOnboarding = true
                showPermissionGuide = false
            }
        }
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        HStack {
            Image("MenuBarIcon")
                .resizable()
                .renderingMode(.template)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("AutoToggle")
                    .font(.headline)
                // 配置方案切换
                Menu {
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
                } label: {
                    Text(profileManager.activeProfile?.name ?? "配置1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
            }

            Spacer()

            // 主界面按钮
            Button("主界面") {
                onOpenMainWindow()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("打开主界面")

            // 防睡眠快捷开关
            Button(action: { sleepPreventionManager.toggleSystemSleep() }) {
                Image(systemName: sleepPreventionManager.isPreventingSystemSleep ? "moon.zzz.fill" : "moon.zzz")
                    .foregroundStyle(sleepPreventionManager.isPreventingSystemSleep ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help(sleepPreventionManager.isPreventingSystemSleep ? "关闭防系统休眠" : "开启防系统休眠")

            // 暂停/恢复按钮
            Button(action: { menuBarManager.togglePause() }) {
                Image(systemName: menuBarManager.isPaused ? "play.circle" : "pause.circle")
                    .foregroundStyle(menuBarManager.isPaused ? .orange : .secondary)
            }
            .buttonStyle(.borderless)
            .help(menuBarManager.isPaused ? "恢复规则执行" : "暂停所有规则")

            // 关闭/退出按钮
            Button(action: { menuBarManager.quitApp() }) {
                Image(systemName: "power")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("退出 AutoToggle")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    /// 定时任务（与被管理应用一上一下平分中间区域）
    private var scheduledTasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("定时任务")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(upcomingTriggers) { item in
                        HStack(spacing: 10) {
                            // app 图标（与「被管理应用」统一）
                            if let icon = AppIconProvider.icon(for: item.bundleID) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.appName)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(item.isLaunch ? "打开" : "退出")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(formatTriggerTime(item.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            // 启用/禁用开关（绑定规则真实状态，可双向切换）
                            Toggle("", isOn: Binding(
                                get: { item.isEnabled },
                                set: { _ in
                                    ruleManager.toggleRule(id: item.id)
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding(.bottom, 6)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("暂无被管理的应用")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    /// 被管理应用列表
    private var managedAppsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("被管理应用")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(managedApps) { app in
                        ManagedAppRow(
                            app: app,
                            idleState: idleDetectorManager.idleState(for: app.bundleID),
                            onQuit: { appActionManager.terminateApp(bundleID: app.bundleID) },
                            onActivate: { appActionManager.activateApp(bundleID: app.bundleID) }
                        )

                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }

    /// 底部信息栏（已移除，规则统计与操作按钮并入标题栏）

    // MARK: - 辅助

    /// 被管理应用列表（合并规则目标 + 运行状态）
    private var managedApps: [AppInfo] {
        let managedBundleIDs = ruleManager.enabledRules.map(\.appBundleID)
        let running = appMonitorManager.runningApps.filter { managedBundleIDs.contains($0.bundleID) }
        return running
    }

    /// 定时任务列表（含已禁用的任务，右侧开关可切换状态）
    private var upcomingTriggers: [UpcomingScheduledTrigger] {
        scheduleManager.upcomingScheduledTriggers(limit: 3)
    }

    /// 更新菜单栏统计
    private func updateStats() {
        menuBarManager.updateStats(activeRules: ruleManager.enabledRules.count)
    }

    /// 格式化触发时间：今天/明天 + HH:mm，其它显示 MM-dd HH:mm
    private func formatTriggerTime(_ date: Date) -> String {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        let timeString = time.string(from: date)

        if Calendar.current.isDateInToday(date) {
            return "今天 \(timeString)"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "明天 \(timeString)"
        }

        let full = DateFormatter()
        full.dateFormat = "MM-dd HH:mm"
        return full.string(from: date)
    }
}
