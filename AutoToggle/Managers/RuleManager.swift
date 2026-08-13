import SwiftUI
import SwiftData

/// 规则管理器
/// 负责规则的 CRUD 操作、持久化和查询
/// 限定在主 Actor 上运行，与 SwiftData 的 MainActor 约束保持一致
@MainActor
@Observable
final class RuleManager {
    /// SwiftData 模型上下文
    private let modelContext: ModelContext
    /// 日志管理器引用
    private weak var logManager: LogManager?
    /// 配置方案管理器引用
    private weak var profileManager: ProfileManager?

    /// 所有已启用的规则（缓存，从 SwiftData 同步）
    private(set) var enabledRules: [AppRule] = []

    /// 所有规则（含禁用）
    private(set) var allRules: [AppRule] = []

    // MARK: - 初始化

    init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
        refreshRules()
    }

    /// 注入日志管理器
    func configure(logManager: LogManager) {
        self.logManager = logManager
    }

    /// 注入配置方案管理器
    func configure(profileManager: ProfileManager) {
        self.profileManager = profileManager
    }

    // MARK: - CRUD

    /// 添加新规则
    func addRule(_ rule: AppRule) {
        // 自动关联到活跃配置方案
        if let activeProfile = profileManager?.activeProfile {
            rule.profile = activeProfile
        }
        modelContext.insert(rule)
        saveChanges()
        logManager?.addSystem(message: "添加规则: \(rule.shortDescription) - \(rule.appName)")
    }

    /// 更新现有规则
    func updateRule(_ rule: AppRule) {
        saveChanges()
    }

    /// 删除规则
    func deleteRule(_ rule: AppRule) {
        let desc = rule.shortDescription
        let name = rule.appName
        modelContext.delete(rule)
        saveChanges()
        logManager?.addSystem(message: "删除规则: \(desc) - \(name)")
    }

    /// 切换规则启用/禁用
    func toggleRule(_ rule: AppRule) {
        rule.isEnabled.toggle()
        saveChanges()
    }

    // MARK: - 查询

    /// 刷新规则缓存
    func refreshRules() {
        let fetchDescriptor = FetchDescriptor<AppRule>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let rules = try? modelContext.fetch(fetchDescriptor) else {
            allRules = []
            enabledRules = []
            return
        }
        allRules = rules
        enabledRules = rules.filter(\.isEnabled)
    }

    /// 获取所有受规则管理的应用 Bundle ID 集合
    func managedBundleIDs() -> Set<String> {
        Set(enabledRules.map(\.appBundleID))
    }

    // MARK: - 内部方法

    /// 保存变更并刷新缓存
    private func saveChanges() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
            refreshRules()
        } catch {
            NSLog("[RuleManager] 保存规则失败: %@", error.localizedDescription)
        }
    }
}
