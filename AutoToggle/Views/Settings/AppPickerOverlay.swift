import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 应用选择器内嵌视图
/// 支持全应用字母分组浏览、搜索过滤、取消按钮、Finder 选取按钮
struct AppPickerOverlay: View {
    /// 选择回调
    let onSelect: (AppInfo) -> Void
    /// 取消回调（返回规则编辑视图）
    let onDismiss: () -> Void

    /// 搜索关键词
    @State private var searchText = ""
    /// 所有已安装应用
    @State private var allApps: [AppInfo] = []
    /// 是否正在加载
    @State private var isLoading = true
    /// 搜索框是否聚焦（打开时自动聚焦）
    @FocusState private var isSearchFocused: Bool

    /// 按首字母分组的应用（分组与排序均遵循当前界面语言）
    private var groupedApps: [(letter: String, apps: [AppInfo])] {
        let filtered = searchText.isEmpty
            ? allApps
            : allApps.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleID.localizedCaseInsensitiveContains(searchText)
            }

        let grouped = Dictionary(grouping: filtered) { app in
            AppSortHelper.indexLetter(for: app.displayName)
        }

        return grouped
            .map { (letter: $0.key, apps: AppSortHelper.sorted($0.value)) }
            .sorted { AppSortHelper.isOrderedBefore($0.letter, $1.letter) }
    }

    /// 所有分组字母（用于快速索引）
    private var allLetters: [String] {
        groupedApps.map(\.letter)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏 + 按钮
            searchToolbar

            Divider()

            // 应用列表
            if isLoading {
                loadingView
            } else {
                appListView
            }

            Divider()

            // 底部按钮
            bottomToolbar
        }
        .onAppear {
            loadAllApps()
            // 自动将光标置于搜索框，方便直接输入
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFocused = true
            }
        }
    }

    // MARK: - 搜索工具栏

    private var searchToolbar: some View {
        HStack(spacing: 8) {
            // 搜索图标 + 输入框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TextField(String(localized: "appPicker.search"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 加载状态

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(String(localized: "appPicker.loading"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 应用列表

    private var appListView: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                // 主列表
                List {
                    ForEach(groupedApps, id: \.letter) { group in
                        Section {
                            ForEach(group.apps) { app in
                                appRow(app)
                            }
                        } header: {
                            Text(group.letter)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .id(group.letter)
                        }
                    }
                }
                .listStyle(.plain)

                // 快速索引（仅未搜索时显示，支持点击跳转）
                if searchText.isEmpty && allLetters.count > 3 {
                    alphabetIndex(proxy: proxy)
                }
            }
        }
    }

    /// 右侧字母表快速索引：点击字母跳转到对应分组
    private func alphabetIndex(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 1) {
            ForEach(allLetters, id: \.self) { letter in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                } label: {
                    Text(letter)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 16)
        .padding(.vertical, 8)
    }

    // MARK: - 应用行

    private func appRow(_ app: AppInfo) -> some View {
        Button(action: { onSelect(app) }) {
            HStack(spacing: 12) {
                if let icon = AppIconProvider.icon(for: app.bundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部工具栏

    private var bottomToolbar: some View {
        HStack {
            Button(String(localized: "appPicker.chooseFinder")) {
                chooseFromFinder()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Text(String(localized: "appPicker.count \(allApps.count)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(String(localized: "appPicker.cancel")) {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 数据加载

    private func loadAllApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let results = BundleHelper.allInstalledApps()

            DispatchQueue.main.async {
                self.allApps = results
                self.isLoading = false
            }
        }
    }

    /// 使用 Finder 选择 .app 文件
    private func chooseFromFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = String(localized: "appPicker.finderMessage")

        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }

            // 从 .app bundle 中提取信息
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier else { return }

            let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent

            let app = AppInfo(
                bundleID: bundleID,
                displayName: name,
                appPath: url.path
            )
            onSelect(app)
        }
    }
}
