import SwiftUI

/// 时间触发条件选择器
/// 允许用户选择小时:分钟、触发星期和退出策略
struct TimeTriggerPicker: View {
    @Binding var trigger: TimeTrigger
    /// 退出策略：nil = 优雅退出，force = 强制退出
    @Binding var quitStrategy: String?
    /// 是否为退出类型（显示退出策略选项）
    var isQuitType: Bool = false

    /// 星期选项（1=周日 ... 7=周六）
    private var weekdays: [(Int, String)] {
        [
            (1, String(localized: "周日")), (2, String(localized: "周一")), (3, String(localized: "周二")), (4, String(localized: "周三")),
            (5, String(localized: "周四")), (6, String(localized: "周五")), (7, String(localized: "周六")),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 时间选择
            VStack(alignment: .leading, spacing: 8) {
                Text("触发时间")
                    .font(.headline)

                HStack(spacing: 8) {
                    Picker("小时", selection: Binding(
                        get: { trigger.hour },
                        set: { trigger.hour = $0 }
                    )) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour))
                                .tag(hour)
                                .font(.title3.monospacedDigit())
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 90)

                    Text(":")
                        .font(.title)
                        .fontWeight(.bold)

                    Picker("分钟", selection: Binding(
                        get: { trigger.minute },
                        set: { trigger.minute = $0 }
                    )) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(String(format: "%02d", minute))
                                .tag(minute)
                                .font(.title3.monospacedDigit())
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 90)
                }
                .frame(height: 120)
            }

            Divider()

            // 星期选择
            VStack(alignment: .leading, spacing: 8) {
                Text("触发日期")
                    .font(.headline)

                HStack(spacing: 6) {
                    ForEach(weekdays, id: \.0) { day, name in
                        weekdayButton(day: day, name: name)
                    }
                }

                // 快捷选择
                HStack(spacing: 8) {
                    quickButton(String(localized: "每天"), weekdays: Set(1...7))
                    quickButton(String(localized: "工作日"), weekdays: Set(2...6))
                    quickButton(String(localized: "周末"), weekdays: Set([1, 7]))
                }
            }

            // 退出策略（仅退出类型显示）
            if isQuitType {
                Divider()

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
        }
        .padding(16)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 星期按钮

    private func weekdayButton(day: Int, name: String) -> some View {
        let isSelected = trigger.weekdays.isEmpty || trigger.weekdays.contains(day)

        return Button(action: { toggleWeekday(day) }) {
            Text(name)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .frame(width: 36, height: 30)
                .background(isSelected ? AnyShapeStyle(.blue) : AnyShapeStyle(.quaternary))
                .foregroundStyle(isSelected ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 快捷按钮

    private func quickButton(_ label: String, weekdays: Set<Int>) -> some View {
        let isActive = trigger.weekdays == weekdays || (trigger.weekdays.isEmpty && weekdays.count == 7)

        return Button(label) {
            trigger.weekdays = weekdays
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(isActive ? .blue : nil)
    }

    /// 切换某个日期的选中状态
    private func toggleWeekday(_ day: Int) {
        // 如果当前为空（表示每天），先初始化为全部选中再移除
        if trigger.weekdays.isEmpty {
            trigger.weekdays = Set(1...7)
        }

        if trigger.weekdays.contains(day) {
            trigger.weekdays.remove(day)
            // 如果全部取消，恢复为每天
            if trigger.weekdays.isEmpty {
                trigger.weekdays = Set(1...7)
            }
        } else {
            trigger.weekdays.insert(day)
        }
    }
}
