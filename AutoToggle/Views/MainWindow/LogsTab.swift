import SwiftUI

/// 日志查看器标签页
/// 支持活动日志和系统日志的切换和浏览
struct LogsTab: View {
    @Environment(LogManager.self) private var logManager

    /// 当前查看的日志分类
    @State private var selectedCategory: LogCategory = .activity
    /// 是否显示清除确认弹窗
    @State private var showClearConfirmation = false
    /// 日志列表自动刷新
    @State private var refreshTrigger = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar

            Divider()

            // 日志列表
            logList
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack {
            // 分类选择器
            Picker("分类", selection: $selectedCategory) {
                Text("活动日志").tag(LogCategory.activity)
                Text("系统日志").tag(LogCategory.system)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Spacer()

            // 日志条数
            Text("\(entries.count) 条记录")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 清除按钮
            Button(action: { showClearConfirmation = true }) {
                Label("清除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .help("清除当前分类的所有日志")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .alert("清除日志", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                clearCurrentLogs()
            }
        } message: {
            Text("确定要清除所有「\(selectedCategory == .activity ? "活动" : "系统")」日志吗？此操作不可撤销。")
        }
    }

    // MARK: - 日志列表

    private var logList: some View {
        Group {
            if entries.isEmpty {
                emptyLogView
            } else {
                List {
                    ForEach(entries) { entry in
                        LogRow(entry: entry)
                    }
                }
                .listStyle(.inset)
                .id(refreshTrigger)
            }
        }
    }

    private var emptyLogView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("暂无\(selectedCategory == .activity ? "活动" : "系统")日志")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 当前分类的日志条目
    private var entries: [LogEntry] {
        logManager.entries(for: selectedCategory)
    }

    // MARK: - 操作

    private func clearCurrentLogs() {
        logManager.clear(category: selectedCategory)
        refreshTrigger = UUID()
    }
}

// MARK: - 单条日志行

struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 级别图标
            Image(systemName: levelIcon)
                .font(.caption)
                .foregroundStyle(levelColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(formatTime(entry.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let appName = entry.relatedAppName {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(appName)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 辅助

    private var levelIcon: String {
        switch entry.level {
        case .info: return "i.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
