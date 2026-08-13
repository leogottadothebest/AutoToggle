import SwiftUI

/// App 规则管理标签页
/// 通过 Binding 将编辑状态传递给父视图（MainWindowView），使用内嵌 overlay 而非 sheet
struct AppTab: View {
    @Environment(RuleManager.self) private var ruleManager
    @Environment(AppMonitorManager.self) private var appMonitorManager
    @Environment(ProfileManager.self) private var profileManager

    /// 绑定到 MainWindowView 的编辑状态
    @Binding var showRuleEditor: Bool
    /// 正在编辑的规则（nil 表示新建）
    @Binding var editingRule: AppRule?

    /// 搜索关键词
    @State private var searchText = ""

    /// 删除方案确认弹窗
    @State private var showDeleteProfileAlert = false
    /// 待删除的方案
    @State private var profileToDelete: Profile?

    /// 重命名方案弹窗
    @State private var showRenameProfileAlert = false
    /// 重命名输入
    @State private var renameText = ""

    /// 过滤后的规则列表
    private var filteredRules: [AppRule] {
        if searchText.isEmpty {
            return ruleManager.allRules
        }
        return ruleManager.allRules.filter {
            $0.appName.localizedCaseInsensitiveContains(searchText) ||
            $0.appBundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 配置方案管理
            profileToolbar

            Divider()

            // 头部工具栏
            headerToolbar

            Divider()

            // 规则列表
            if filteredRules.isEmpty && !searchText.isEmpty {
                noSearchResultsView
            } else if ruleManager.allRules.isEmpty {
                emptyStateView
            } else {
                ruleList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("删除配置方案", isPresented: $showDeleteProfileAlert) {
            Button("取消", role: .cancel) {
                profileToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let profile = profileToDelete {
                    profileManager.deleteProfile(profile)
                }
                profileToDelete = nil
            }
        } message: {
            if let profile = profileToDelete {
                Text("确定要删除配置方案「\(profile.name)」吗？其中的所有规则将被永久删除。此操作不可撤销。")
            }
        }
    }

    // MARK: - 配置方案管理

    private var profileToolbar: some View {
        HStack(spacing: 8) {
            // 方案切换菜单
            Menu {
                ForEach(profileManager.profiles) { profile in
                    Button {
                        profileManager.activateProfile(profile)
                    } label: {
                        HStack {
                            Text(profile.name)
                            if profile.isActive {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.subheadline)
                    Text(profileManager.activeProfile?.name ?? "配置1")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // 新建方案
            Button {
                let existingCount = profileManager.profiles.filter { $0.name.hasPrefix("配置") }.count
                let newName = "配置\(existingCount + 1)"
                profileManager.createProfile(name: newName, setActive: false)
            } label: {
                Label("新建", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .help("新建配置方案")

            // 重命名
            Button {
                if let active = profileManager.activeProfile {
                    renameText = active.name
                    showRenameProfileAlert = true
                }
            } label: {
                Label("重命名", systemImage: "pencil")
                    .labelStyle(.iconOnly)
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .help("重命名当前配置方案")
            .alert("重命名配置方案", isPresented: $showRenameProfileAlert) {
                TextField("方案名称", text: $renameText)
                Button("取消", role: .cancel) { renameText = "" }
                Button("确定") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let active = profileManager.activeProfile {
                        profileManager.renameProfile(active, to: trimmed)
                    }
                }
            } message: {
                Text("为当前配置方案输入新名称")
            }

            // 导入
            Button {
                profileManager.beginImport()
            } label: {
                Label("导入", systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .help("导入配置方案")

            // 删除
            if profileManager.profiles.count > 1 {
                Button {
                    if let active = profileManager.activeProfile {
                        profileToDelete = active
                        showDeleteProfileAlert = true
                    }
                } label: {
                    Label("删除", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .help("删除当前配置方案")
            }

            // 导出
            if let active = profileManager.activeProfile {
                Button {
                    profileManager.exportProfile(active)
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .help("导出当前配置方案")
            }

            Spacer()

            Text("\(profileManager.activeProfile?.rules?.count ?? 0) 条规则")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 头部工具栏

    private var headerToolbar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("应用规则")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    editingRule = nil
                    showRuleEditor = true
                }) {
                    Label("添加规则", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // 搜索栏
            if !ruleManager.allRules.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索规则...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - 规则列表

    private var ruleList: some View {
        List {
            ForEach(filteredRules) { rule in
                RuleRow(rule: rule) {
                    editingRule = rule
                    showRuleEditor = true
                }
                    .swipeActions(edge: .trailing) {
                        Button("删除", role: .destructive) {
                            ruleManager.deleteRule(rule)
                        }
                    }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("还没有任何规则")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("添加定时或闲置规则，让 AutoToggle 自动管理你的应用")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("添加第一条规则") {
                editingRule = nil
                showRuleEditor = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("未找到匹配「\(searchText)」的规则")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 规则行视图

struct RuleRow: View {
    let rule: AppRule
    /// 编辑回调
    var onEdit: (() -> Void)?

    @Environment(RuleManager.self) private var ruleManager
    @Environment(AppMonitorManager.self) private var appMonitorManager

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let icon = AppIconProvider.icon(for: rule.appBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
            }

            // 规则信息
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.appName)
                    .font(.headline)

                Text(rule.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // 右侧控件组：运行状态 + 编辑 + 开关（紧贴右侧）
            HStack(spacing: 8) {
                if appMonitorManager.isAppRunning(bundleID: rule.appBundleID) {
                    Label("运行中", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("未运行", systemImage: "circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("修改规则")
                }
                Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in ruleManager.toggleRule(rule) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            }
            .fixedSize()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
