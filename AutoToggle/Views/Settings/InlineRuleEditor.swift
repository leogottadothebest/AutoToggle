import SwiftUI

/// 规则编辑内嵌视图
/// 作为 overlay 在主窗口内部居中显示，App 选择器也在同一层级内切换
struct InlineRuleEditor: View {
    /// 编辑模式：nil 表示新建，非 nil 表示编辑已有规则
    let editingRule: AppRule?
    /// 关闭编辑器回调
    let onDismiss: () -> Void
    /// 是否有未保存的更改（绑定到父视图）
    @Binding var hasUnsavedChanges: Bool
    /// 父视图请求保存（绑定）
    @Binding var saveRequested: Bool

    @Environment(RuleManager.self) private var ruleManager

    // MARK: - 表单状态

    @State private var selectedApp: AppInfo?
    @State private var ruleType: RuleType = .idleQuit
    @State private var timeTrigger: TimeTrigger = TimeTrigger()
    @State private var idleTrigger: IdleTrigger = IdleTrigger()
    @State private var quitStrategy: String? = nil

    /// 是否显示 App 选择器（替换表单内容区域）
    @State private var isShowingAppPicker = false

    /// 表单是否有效
    private var isValid: Bool {
        selectedApp != nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerBar

            Divider()

            // 内容区域
            if isShowingAppPicker {
                AppPickerOverlay(
                    onSelect: { app in
                        selectedApp = app
                        isShowingAppPicker = false
                    },
                    onDismiss: {
                        isShowingAppPicker = false
                    }
                )
            } else {
                formContent
            }

            Divider()

            // 底部操作栏
            bottomBar
        }
        .onAppear {
            loadEditingRule()
        }
        .onChange(of: selectedApp) { _, _ in hasUnsavedChanges = true }
        .onChange(of: ruleType) { _, _ in hasUnsavedChanges = true }
        .onChange(of: timeTrigger) { _, _ in hasUnsavedChanges = true }
        .onChange(of: idleTrigger) { _, _ in hasUnsavedChanges = true }
        .onChange(of: saveRequested) { _, newValue in
            if newValue {
                saveRule()
                saveRequested = false
                hasUnsavedChanges = false
                onDismiss()
            }
        }
    }

    // MARK: - 标题栏

    private var headerBar: some View {
        HStack {
            Text(editingRule == nil
                 ? String(localized: "editor.newRule")
                 : String(localized: "editor.editRule"))
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 表单内容

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 应用选择
                appSelectionSection

                // 规则类型选择
                ruleTypeSection

                // 触发条件编辑器
                triggerEditorSection
            }
            .padding(20)
        }
    }

    // MARK: - 应用选择

    private var appSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "editor.targetApp"))
                .font(.headline)

            Button(action: { isShowingAppPicker = true }) {
                HStack(spacing: 12) {
                    if let app = selectedApp {
                        if let icon = AppIconProvider.icon(for: app.bundleID) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(app.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                        Text(String(localized: "editor.searchApp"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 规则类型选择

    private var ruleTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "editor.triggerType"))
                .font(.headline)

            Picker("", selection: $ruleType) {
                ForEach(RuleType.allCases, id: \.self) { type in
                    Text(type.localizedName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - 触发条件编辑器

    @ViewBuilder
    private var triggerEditorSection: some View {
        switch ruleType {
        case .scheduledLaunch, .scheduledQuit:
            TimeTriggerPicker(
                trigger: $timeTrigger,
                quitStrategy: $quitStrategy,
                isQuitType: ruleType == .scheduledQuit
            )
        case .idleQuit, .idleHide:
            IdleTriggerPicker(
                trigger: $idleTrigger,
                quitStrategy: $quitStrategy,
                isQuitType: ruleType == .idleQuit
            )
        }
    }

    // MARK: - 底部操作栏

    private var bottomBar: some View {
        HStack {
            if let rule = editingRule {
                Button(String(localized: "editor.deleteRule"), role: .destructive) {
                    ruleManager.deleteRule(rule)
                    hasUnsavedChanges = false
                    onDismiss()
                }
            }
            Spacer()
            Button(String(localized: "editor.cancel")) {
                hasUnsavedChanges = false
                onDismiss()
            }
                .keyboardShortcut(.cancelAction)
            Button(String(localized: "editor.save")) {
                saveRule()
                hasUnsavedChanges = false
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
            .disabled(!isValid)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 数据加载和保存

    private func loadEditingRule() {
        guard let rule = editingRule else { return }

        selectedApp = AppInfo(
            bundleID: rule.appBundleID,
            displayName: rule.appName,
            appPath: BundleHelper.appPath(for: rule.appBundleID)
        )
        ruleType = rule.ruleType
        quitStrategy = rule.quitStrategyOverride

        if let tt = rule.timeTrigger {
            timeTrigger = tt
        }
        if let it = rule.idleTrigger {
            idleTrigger = it
        }
    }

    private func saveRule() {
        guard let app = selectedApp else { return }

        if let existingRule = editingRule {
            existingRule.appBundleID = app.bundleID
            existingRule.appName = app.displayName
            existingRule.ruleType = ruleType
            existingRule.quitStrategyOverride = quitStrategy
            existingRule.timeTrigger = ruleType.isScheduled ? timeTrigger : nil
            existingRule.idleTrigger = ruleType.isIdle ? idleTrigger : nil
            ruleManager.updateRule(existingRule)
        } else {
            let newRule = AppRule(
                appBundleID: app.bundleID,
                appName: app.displayName,
                ruleType: ruleType,
                timeTrigger: ruleType.isScheduled ? timeTrigger : nil,
                idleTrigger: ruleType.isIdle ? idleTrigger : nil
            )
            newRule.quitStrategyOverride = quitStrategy
            ruleManager.addRule(newRule)
        }
    }
}

// MARK: - RuleType 本地化扩展

extension RuleType {
    var localizedName: String {
        switch self {
        case .scheduledLaunch: return String(localized: "ruleType.scheduledLaunch")
        case .scheduledQuit: return String(localized: "ruleType.scheduledQuit")
        case .idleQuit: return String(localized: "ruleType.idleQuit")
        case .idleHide: return String(localized: "ruleType.idleHide")
        }
    }
}
