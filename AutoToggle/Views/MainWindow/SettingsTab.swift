import SwiftUI
import ServiceManagement

/// 通用设置标签页
/// 迁移自原 GeneralSettingsView，增加日志保留天数设置
struct SettingsTab: View {
    /// 是否开机自启
    @State private var launchAtLogin: Bool = false

    /// 退出前是否发送通知提醒
    @AppStorage("notifyBeforeQuit") private var notifyBeforeQuit: Bool = true

    /// 通知提前秒数
    @AppStorage("notifySecondsBeforeQuit") private var notifySecondsBeforeQuit: Int = 30

    /// 外观设置
    @Environment(AppearanceManager.self) private var appearanceManager

    /// 语言设置
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    /// 时区设置（存储时区标识；"system" = 跟随系统）
    @AppStorage("scheduleTimeZone") private var scheduleTimeZone: String = ScheduleTimeZone.systemIdentifier

    /// 调度管理器（时区变化时立即重新评估）
    @Environment(ScheduleManager.self) private var scheduleManager

    /// 防睡眠管理器
    @Environment(SleepPreventionManager.self) private var sleepPreventionManager

    /// 日志保留 - 活动日志
    @AppStorage("activityLogRetentionDays") private var activityLogRetentionDays: Int = 30
    @AppStorage("activityMaxEntries") private var activityMaxEntries: Int = 500

    /// 日志保留 - 系统日志
    @AppStorage("systemLogRetentionDays") private var systemLogRetentionDays: Int = 90
    @AppStorage("systemMaxLogSizeMB") private var systemMaxLogSizeMB: Int = 10

    @Environment(LogManager.self) private var logManager

    @State private var showRestartPrompt = false

    var body: some View {
        Form {
            // 启动设置
            Section {
                Toggle("登录时自动启动 AutoToggle", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            } header: {
                Text("启动")
            } footer: {
                Text("AutoToggle 将在菜单栏安静运行，不占用 Dock 空间。")
            }

            // 通知设置
            Section {
                Toggle("退出应用前发送通知", isOn: $notifyBeforeQuit)

                if notifyBeforeQuit {
                    Picker("提前通知时间", selection: $notifySecondsBeforeQuit) {
                        Text("10 秒").tag(10)
                        Text("30 秒").tag(30)
                        Text("60 秒").tag(60)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("通知")
            } footer: {
                Text("当闲置规则触发时，AutoToggle 将在退出应用前发送系统通知。")
            }

            // 时区设置
            Section {
                Picker("时区", selection: $scheduleTimeZone) {
                    Text("跟随系统").tag(ScheduleTimeZone.systemIdentifier)
                    ForEach(Self.commonTimeZones, id: \.0) { identifier, name in
                        Text(timeZoneLabel(identifier: identifier, name: name))
                            .tag(identifier)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: scheduleTimeZone) { _, _ in
                    scheduleManager.reevaluate()
                }
            } header: {
                Text("时区")
            } footer: {
                Text("定时规则将按所选时区触发，默认跟随系统时区。")
            }

            // 防睡眠设置
            Section {
                Toggle("防止系统休眠", isOn: Binding(
                    get: { sleepPreventionManager.isPreventingSystemSleep },
                    set: { sleepPreventionManager.setSystemSleepPrevention($0) }
                ))

                Toggle("防止显示器关闭", isOn: Binding(
                    get: { sleepPreventionManager.isPreventingDisplaySleep },
                    set: { sleepPreventionManager.setDisplaySleepPrevention($0) }
                ))
            } header: {
                Text("防睡眠")
            } footer: {
                Text("防止 Mac 因闲置进入系统休眠或关闭显示器（熄屏但不休眠）。")
            }

            // 外观设置
            Section {
                Picker("外观", selection: Binding(
                    get: { appearanceManager.selectedMode.rawValue },
                    set: { newValue in
                        if let mode = AppearanceManager.AppearanceMode(rawValue: newValue) {
                            appearanceManager.selectedMode = mode
                        }
                    }
                )) {
                    Text("跟随系统").tag("system")
                    Text("浅色模式").tag("light")
                    Text("深色模式").tag("dark")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("外观")
            } footer: {
                Text("选择「跟随系统」将自动匹配 macOS 的外观设置。")
            }

            // 语言设置
            Section {
                Picker("界面语言", selection: $appLanguage) {
                    Text("跟随系统").tag("system")
                    Text("中文").tag("zh-Hans")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
                .onChange(of: appLanguage) { _, _ in
                    // 语言切换需要重启应用才能完全生效
                    showRestartPrompt = true
                }
            } header: {
                Text("语言")
            } footer: {
                Text("切换语言后需要重启应用以完全生效。")
            }
            .alert("需要重启", isPresented: $showRestartPrompt) {
                Button("稍后重启", role: .cancel) {}
                Button("立即重启") {
                    restartApp()
                }
            } message: {
                Text("语言设置将在重启 AutoToggle 后生效。")
            }

            // 活动日志设置
            Section {
                HStack {
                    Text("保留时间")
                    Spacer()
                    TextField("", value: $activityLogRetentionDays, format: .number.grouping(.never))
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                    Text(activityLogRetentionDays == 0 ? "永久" : "天")
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                    Stepper("", value: $activityLogRetentionDays, in: 0...3650)
                        .labelsHidden()
                }
                .onChange(of: activityLogRetentionDays) { _, _ in
                    logManager.enforceRetentionPolicy()
                }

                HStack {
                    Text("日志上限")
                    Spacer()
                    TextField("", value: $activityMaxEntries, format: .number.grouping(.never))
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                    Text(activityMaxEntries == 0 ? "无限制" : "条")
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                    Stepper("", value: $activityMaxEntries, in: 0...100000, step: 100)
                        .labelsHidden()
                }
                .onChange(of: activityMaxEntries) { _, _ in
                    logManager.enforceRetentionPolicy()
                }
            } header: {
                Text("活动日志")
            } footer: {
                Text("设置 0 表示永久保留/无限制。超过限制的旧日志将被自动清理。")
            }

            // 系统日志设置
            Section {
                HStack {
                    Text("保留时间")
                    Spacer()
                    TextField("", value: $systemLogRetentionDays, format: .number.grouping(.never))
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                    Text(systemLogRetentionDays == 0 ? "永久" : "天")
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                    Stepper("", value: $systemLogRetentionDays, in: 0...3650)
                        .labelsHidden()
                }
                .onChange(of: systemLogRetentionDays) { _, _ in
                    logManager.enforceRetentionPolicy()
                }

                HStack {
                    Text("文件大小上限")
                    Spacer()
                    TextField("", value: $systemMaxLogSizeMB, format: .number.grouping(.never))
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                    Text(systemMaxLogSizeMB == 0 ? "无限制" : "MB")
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                    Stepper("", value: $systemMaxLogSizeMB, in: 0...10240, step: 10)
                        .labelsHidden()
                }
                .onChange(of: systemMaxLogSizeMB) { _, _ in
                    logManager.enforceRetentionPolicy()
                }
            } header: {
                Text("系统日志")
            } footer: {
                Text("设置 0 表示永久保留/无限制。超过文件大小上限的旧日志将被自动清理。")
            }

            // 关于
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("最低系统要求")
                    Spacer()
                    Text("macOS 26.0 (Apple Silicon)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("关于 AutoToggle")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checkLaunchAtLogin()
        }
    }

    // MARK: - 时区

    /// 常见时区（标识 + 显示名）
    private static let commonTimeZones: [(String, String)] = [
        ("Asia/Shanghai", "北京 / 上海"),
        ("Asia/Hong_Kong", "香港"),
        ("Asia/Taipei", "台北"),
        ("Asia/Singapore", "新加坡"),
        ("Asia/Tokyo", "东京"),
        ("Asia/Seoul", "首尔"),
        ("Asia/Bangkok", "曼谷"),
        ("Asia/Kolkata", "新德里"),
        ("Asia/Dubai", "迪拜"),
        ("Europe/Moscow", "莫斯科"),
        ("Europe/Paris", "巴黎"),
        ("Europe/Berlin", "柏林"),
        ("Europe/London", "伦敦"),
        ("Africa/Cairo", "开罗"),
        ("America/New_York", "纽约"),
        ("America/Chicago", "芝加哥"),
        ("America/Denver", "丹佛"),
        ("America/Los_Angeles", "洛杉矶"),
        ("America/Sao_Paulo", "圣保罗"),
        ("Pacific/Auckland", "奥克兰"),
        ("Pacific/Honolulu", "檀香山"),
    ]

    /// 时区显示名（附当前 UTC 偏移，DST 时自动变化）
    private func timeZoneLabel(identifier: String, name: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else { return name }
        let seconds = timeZone.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "-"
        let absSeconds = abs(seconds)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        let offset = minutes == 0 ? "\(sign)\(hours)" : "\(sign)\(hours):\(String(format: "%02d", minutes))"
        return "\(name)（GMT\(offset)）"
    }

    // MARK: - 开机自启

    private func checkLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[SettingsTab] 切换登录自启失败: \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    /// 重启应用
    private func restartApp() {
        // LOW-9 修复：用非弃用的 Process.run() 替代 launch()，executableURL 替代 launchPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }
}
