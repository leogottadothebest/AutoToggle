import SwiftData

/// 应用 SwiftData Schema（版本化入口）。
///
/// 当前为 V1（AppRule / LogEntry / Profile 三个 @Model）。
/// 未来给 @Model 加/改/删字段时，务必走版本化迁移，否则旧用户的 store 会因 schema
/// 不匹配而打不开（升级即数据丢失/崩溃）：
/// 1. 新增 `SchemaV2: VersionedSchema`（声明 `versionIdentifier` 与字段变更）；
/// 2. 新增 `AppMigrationPlan: SchemaMigrationPlan`，注册轻量（或自定义）迁移 stage；
/// 3. `ModelContainer(for: migrationPlan:)` 传入该计划。
enum AppSchema {
    /// 统一 Schema（供 ModelContainer 使用，替代裸 `for: AppRule.self, LogEntry.self, Profile.self`）。
    /// 保持默认 store URL（~/Library/Application Support/default.store）不变。
    static let schema = Schema([
        AppRule.self,
        LogEntry.self,
        Profile.self,
    ])
}
