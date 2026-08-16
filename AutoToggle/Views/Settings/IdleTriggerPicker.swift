import SwiftUI

/// 闲置触发条件选择器
/// 允许用户选择闲置分钟数，以及（退出类型时）退出策略
struct IdleTriggerPicker: View {
    @Binding var trigger: IdleTrigger
    /// 退出策略：nil = 优雅退出，force = 强制退出
    @Binding var quitStrategy: String?
    /// 是否为退出类型（显示退出策略选项，由父规则 ruleType 决定）
    var isQuitType: Bool = false

    /// 预设闲置时长选项（分钟）
    private let presets: [Int] = [1, 3, 5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 闲置时长
            VStack(alignment: .leading, spacing: 8) {
                Text("闲置多久后触发")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                    ForEach(presets, id: \.self) { minutes in
                        presetButton(minutes: minutes)
                    }
                }

                // 自定义时长：手动输入
                customMinutesInput
            }

            // 闲置判定范围
            VStack(alignment: .leading, spacing: 8) {
                Text("闲置判定")
                    .font(.headline)

                Picker("", selection: $trigger.scope) {
                    Text("应用闲置").tag(IdleScope.app)
                    Text("系统闲置").tag(IdleScope.system)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(scopeExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // 退出策略（仅退出类型显示）
            if isQuitType {
                VStack(alignment: .leading, spacing: 8) {
                    Text("退出方式")
                        .font(.headline)

                    Picker("", selection: Binding(
                        get: { quitStrategy ?? "normal" },
                        set: { quitStrategy = $0 == "force" ? "force" : nil }
                    )) {
                        Text("优雅退出").tag("normal")
                        Text("强制退出").tag("force")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    if quitStrategy == "force" {
                        Text("直接终止应用进程，不会提示保存数据")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("优先使用 AppleScript 请求应用保存数据后退出")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 注意事项
            VStack(alignment: .leading, spacing: 4) {
                Text("注意：正在播放音频、会议中的应用不会被自动关闭")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 预设时长按钮

    private func presetButton(minutes: Int) -> some View {
        let isSelected = trigger.idleMinutes == minutes

        return Button(formatMinutes(minutes)) {
            trigger.idleMinutes = minutes
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(isSelected ? .blue : nil)
    }

    // MARK: - 自定义时长

    /// 自定义时长手动输入（分钟），可直接键入或通过步进器增减
    private var customMinutesInput: some View {
        HStack(spacing: 8) {
            Text("自定义")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("", value: Binding(
                get: { trigger.idleMinutes },
                set: { trigger.idleMinutes = max(1, min(1440, $0)) }
            ), format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .multilineTextAlignment(.trailing)
                .labelsHidden()

            Text(String(localized: "unit.minutes"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper("", value: Binding(
                get: { trigger.idleMinutes },
                set: { trigger.idleMinutes = max(1, min(1440, $0)) }
            ), in: 1...1440)
                .labelsHidden()

            Spacer()
        }
    }

    /// 格式化分钟数为可读文本
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "time.minutes \(minutes)")
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return String(localized: "time.hours \(hours)")
        }
        return "\(hours)h\(remaining)m"
    }

    /// 当前闲置判定范围的说明文案
    private var scopeExplanation: String {
        switch trigger.scope {
        case .app:
            return String(localized: "idle.scope.appHint")
        case .system:
            return String(localized: "idle.scope.systemHint")
        }
    }
}
