import Foundation
import SwiftData

/// 配置方案模型
/// 每个方案包含一组规则，用户可在不同方案间切换（如"工作"、"生活"、"游戏"）
@Model
final class Profile {
    /// 唯一标识
    var id: UUID
    /// 方案名称
    var name: String
    /// 创建时间
    var createdAt: Date
    /// 是否为当前活跃方案（同时只有一个生效）
    var isActive: Bool

    /// 关联的规则（级联删除）
    @Relationship(deleteRule: .cascade, inverse: \AppRule.profile)
    var rules: [AppRule]?

    // MARK: - 初始化

    init(
        id: UUID = UUID(),
        name: String = "配置1",
        createdAt: Date = Date(),
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
