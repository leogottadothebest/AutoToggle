import SwiftUI

/// 菜单栏下拉面板主视图
/// 显示被管理应用的运行状态、规则信息和操作入口
struct MenuBarContentView: View {
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

            // 被管理应用列表
            if managedApps.isEmpty {
                emptyStateView
            } else {
                managedAppsListView
            }

            Divider()

            // 底部信息栏
            footerView
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
                    HStack(spacing: 2) {
                        Text(profileManager.activeProfile?.name ?? "配置1")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6))
                            .foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
            }

            Spacer()

            // 防睡眠快捷开关
            Button(action: { sleepPreventionManager.toggleSystemSleep() }) {
                Image(systemName: sleepPreventionManager.isPreventingSystemSleep ? "moon.zzz.fill" : "moon.zzz")
                    .foregroundStyle(sleepPreventionManager.isPreventingSystemSleep ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(sleepPreventionManager.isPreventingSystemSleep ? "关闭防系统休眠" : "开启防系统休眠")

            // 暂停/恢复按钮
            Button(action: { menuBarManager.togglePause() }) {
                Image(systemName: menuBarManager.isPaused ? "play.circle" : "pause.circle")
                    .foregroundStyle(menuBarManager.isPaused ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(menuBarManager.isPaused ? "恢复规则执行" : "暂停所有规则")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
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

            Text("打开主界面添加定时或闲置规则")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("打开主界面") {
                (NSApp.delegate as? AppDelegate)?.showMainWindow()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    /// 被管理应用列表
    private var managedAppsListView: some View {
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
        .frame(maxHeight: 300)
    }

    /// 底部信息栏
    private var footerView: some View {
        VStack(spacing: 4) {
            HStack {
                Label("\(menuBarManager.activeRuleCount) 条规则", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let nextTrigger = scheduleManager.nextTriggerTime {
                    Label(
                        "下次: \(formatTime(nextTrigger))",
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            HStack {
                // 主界面按钮
                Button(action: {
                    (NSApp.delegate as? AppDelegate)?.showMainWindow()
                }) {
                    Label("主界面", systemImage: "rectangle.grid.1x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .controlSize(.small)

                // 退出按钮
                Button(action: { menuBarManager.quitApp() }) {
                    Label("退出", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 辅助

    /// 被管理应用列表（合并规则目标 + 运行状态）
    private var managedApps: [AppInfo] {
        let managedBundleIDs = ruleManager.enabledRules.map(\.appBundleID)
        let running = appMonitorManager.runningApps.filter { managedBundleIDs.contains($0.bundleID) }
        return running
    }

    /// 更新菜单栏统计
    private func updateStats() {
        menuBarManager.updateStats(activeRules: ruleManager.enabledRules.count)
    }

    /// 格式化时间显示
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
