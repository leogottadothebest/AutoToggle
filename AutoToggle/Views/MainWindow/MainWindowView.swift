import SwiftUI

/// AutoToggle 主界面窗口
/// 包含四个功能 Tab：总览、App、日志、设置
/// 规则编辑器使用内嵌 overlay 而非 sheet，统一在主窗口内展示
struct MainWindowView: View {
    /// 当前选中的 Tab
    @State var selectedTab: MainTab = .overview

    // MARK: - 规则编辑 overlay 状态

    /// 是否显示规则编辑 overlay
    @State private var showRuleEditor = false
    /// 正在编辑的规则（nil 表示新建）
    @State private var editingRule: AppRule?
    /// 是否有未保存的更改
    @State private var hasUnsavedChanges = false
    /// 显示未保存更改提醒弹窗
    @State private var showUnsavedAlert = false
    /// 待切换的目标 Tab
    @State private var pendingTab: MainTab?
    /// 触发编辑器保存
    @State private var saveRequested = false

    enum MainTab: String, CaseIterable {
        case overview
        case apps
        case logs
        case settings

        var systemImage: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .apps: return "app.badge"
            case .logs: return "list.bullet.rectangle"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        ZStack {
            // 底层：TabView 内容
            tabContent

            // 顶层：规则编辑 overlay
            if showRuleEditor {
                ruleEditorOverlay
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .animation(.easeInOut(duration: 0.2), value: showRuleEditor)
        .alert("未保存的更改", isPresented: $showUnsavedAlert) {
            Button("取消", role: .cancel) {
                pendingTab = nil
            }
            Button("丢弃", role: .destructive) {
                showRuleEditor = false
                editingRule = nil
                hasUnsavedChanges = false
                if let tab = pendingTab {
                    selectedTab = tab
                    pendingTab = nil
                }
            }
            Button("保存") {
                saveAndDismiss()
            }
        } message: {
            Text("当前编辑的规则尚未保存，是否保存更改？")
        }
    }

    // MARK: - Tab 内容

    private var tabContent: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab != selectedTab {
                    if showRuleEditor && hasUnsavedChanges {
                        pendingTab = newTab
                        showUnsavedAlert = true
                    } else {
                        selectedTab = newTab
                        if showRuleEditor {
                            showRuleEditor = false
                            editingRule = nil
                            hasUnsavedChanges = false
                        }
                    }
                }
            }
        )) {
            OverviewTab(selectedTab: $selectedTab)
                .tabItem {
                    Label(MainTab.overview.localizedName,
                          systemImage: MainTab.overview.systemImage)
                }
                .tag(MainTab.overview)

            AppTab(showRuleEditor: $showRuleEditor, editingRule: $editingRule)
                .tabItem {
                    Label(MainTab.apps.localizedName,
                          systemImage: MainTab.apps.systemImage)
                }
                .tag(MainTab.apps)

            LogsTab()
                .tabItem {
                    Label(MainTab.logs.localizedName,
                          systemImage: MainTab.logs.systemImage)
                }
                .tag(MainTab.logs)

            SettingsTab()
                .tabItem {
                    Label(MainTab.settings.localizedName,
                          systemImage: MainTab.settings.systemImage)
                }
                .tag(MainTab.settings)
        }
    }

    // MARK: - 规则编辑 Overlay

    private var ruleEditorOverlay: some View {
        ZStack {
            // 透明背景（不暗化底层内容）
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissRuleEditor()
                }

            // 居中编辑面板（普通不透明背景）
            InlineRuleEditor(
                editingRule: editingRule,
                onDismiss: {
                    dismissRuleEditor()
                },
                hasUnsavedChanges: $hasUnsavedChanges,
                saveRequested: $saveRequested
            )
            .frame(width: 520, height: 460)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, y: 3)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    // MARK: - 规则编辑器关闭

    private func dismissRuleEditor() {
        if hasUnsavedChanges {
            showUnsavedAlert = true
        } else {
            showRuleEditor = false
            editingRule = nil
            hasUnsavedChanges = false
            if let tab = pendingTab {
                selectedTab = tab
                pendingTab = nil
            }
        }
    }

    private func saveAndDismiss() {
        saveRequested = true
    }
}

// MARK: - MainTab 本地化扩展

extension MainWindowView.MainTab {
    var localizedName: String {
        switch self {
        case .overview: return String(localized: "tab.overview")
        case .apps: return String(localized: "tab.apps")
        case .logs: return String(localized: "tab.logs")
        case .settings: return String(localized: "tab.settings")
        }
    }
}
