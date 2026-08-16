import Foundation
import SwiftData
import AppKit

/// 配置方案管理器
/// 负责配置方案的 CRUD、切换、导入导出
@MainActor
@Observable
final class ProfileManager {
    private let modelContext: ModelContext
    private weak var ruleManager: RuleManager?

    /// 所有配置方案
    private(set) var profiles: [Profile] = []
    /// 当前活跃方案
    private(set) var activeProfile: Profile?

    // MARK: - 初始化

    init(modelContainer: ModelContainer, ruleManager: RuleManager) {
        self.modelContext = modelContainer.mainContext
        self.ruleManager = ruleManager
        refreshProfiles()

        // 如果没有方案，自动创建默认方案
        if profiles.isEmpty {
            let defaultProfile = createProfile(name: String(localized: "profile.defaultName"), setActive: true)
            activeProfile = defaultProfile
        } else if activeProfile == nil {
            // 有方案但没有活跃的，激活第一个
            activateProfile(profiles[0])
        }
    }

    // MARK: - CRUD

    /// 创建新配置方案
    /// - Parameters:
    ///   - name: 方案名称
    ///   - setActive: 是否立即激活
    /// - Returns: 新创建的 Profile
    @discardableResult
    func createProfile(name: String, setActive: Bool = false) -> Profile {
        let profile = Profile(name: name, createdAt: Date(), isActive: false)
        modelContext.insert(profile)

        if setActive {
            activateProfile(profile)
        }

        saveChanges()
        refreshProfiles()
        return profile
    }

    /// 删除配置方案
    func deleteProfile(_ profile: Profile) {
        guard profiles.count > 1 else {
            // 至少保留一个方案
            return
        }

        let wasActive = profile.isActive
        modelContext.delete(profile)
        saveChanges()
        refreshProfiles()

        // 如果删除了活跃方案，激活第一个剩下的方案
        if wasActive, let first = profiles.first {
            activateProfile(first)
        }
    }

    /// 重命名配置方案
    /// - Parameters:
    ///   - profile: 目标方案
    ///   - newName: 新名称（去除首尾空白，超长截断到 64 字符）
    func renameProfile(_ profile: Profile, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 与导入一致的长度限制，避免超长/含控制字符的输入污染 UI 与日志
        profile.name = String(trimmed.prefix(64))
        saveChanges()
        refreshProfiles()
    }

    // MARK: - 激活

    /// 激活指定方案（取消其他所有方案的活跃状态）
    func activateProfile(_ profile: Profile) {
        // 取消所有活跃状态
        for p in profiles where p.isActive {
            p.isActive = false
        }
        // 激活目标方案
        profile.isActive = true
        activeProfile = profile
        saveChanges()

        // 通知 RuleManager 刷新规则缓存
        ruleManager?.refreshRules()
    }

    // MARK: - 导入导出

    /// 导出配置方案到 JSON 文件
    func exportProfile(_ profile: Profile) {
        let exportData = buildExportData(for: profile)

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: exportData,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(profile.name).autotoggle.json"
        panel.message = String(localized: "选择保存位置")

        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            try? jsonData.write(to: url)
        }
    }

    /// 导入允许的最大规则数量（防止 1MB 配置塞入数千条规则导致资源耗尽，MED-3）
    private static let maxImportedRules = 200
    /// 导入文件大小上限（1MB）
    private static let maxImportBytes = 1_048_576

    /// 清洗导入的显示名称：先剥离控制字符（C0/C1/DEL，含换行、制表、退格）再做长度截断，
    /// 避免恶意输入用换行伪造日志行或污染 UI/导出报告（CWE-117）。与 renameProfile 的 trim 互补。
    private static func sanitizeImportedText(_ raw: String, maxLength: Int) -> String {
        let scalars = raw.unicodeScalars.filter { scalar in
            scalar.value >= 0x20 && scalar.value != 0x7F && !(0x80...0x9F).contains(scalar.value)
        }
        return String(scalars.map { String($0) }.joined().prefix(maxLength))
    }

    /// 从 JSON 文件导入配置方案
    func importProfile(from url: URL) -> Profile? {
        // 有界读取（≤1MB+1 哨兵）：既防超大文件内存耗尽（CWE-400），
        // 也消除 symlink 绕过大小检查与 check-then-use TOCTOU（LOW-1/LOW-5）。
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data: Data
        do {
            guard let read = try handle.read(upToCount: Self.maxImportBytes + 1) else {
                return nil
            }
            data = read
        } catch {
            return nil
        }
        guard data.count <= Self.maxImportBytes else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileNameRaw = json["profileName"] as? String,
              let rulesData = json["rules"] as? [[String: Any]] else {
            return nil
        }

        // LOW-2 修复：名称长度截断，避免日志/UI 被超长或含控制字符的输入污染
        let profileName = Self.sanitizeImportedText(profileNameRaw, maxLength: 64)
        let profile = createProfile(name: profileName, setActive: false)

        for ruleDict in rulesData.prefix(Self.maxImportedRules) {
            // 防注入（CWE-94）：Bundle ID 会被拼入 AppleScript，必须严格校验格式
            guard let bundleID = ruleDict["appBundleID"] as? String,
                  BundleHelper.isValidBundleID(bundleID),
                  let appNameRaw = ruleDict["appName"] as? String,
                  let ruleTypeRaw = ruleDict["ruleType"] as? String,
                  let ruleType = RuleType(rawValue: ruleTypeRaw) else {
                continue
            }
            let appName = Self.sanitizeImportedText(appNameRaw, maxLength: 128)
            let isEnabled = ruleDict["isEnabled"] as? Bool ?? true

            var timeTrigger: TimeTrigger?
            if let ttDict = ruleDict["timeTrigger"] as? [String: Any],
               let hour = ttDict["hour"] as? Int,
               let minute = ttDict["minute"] as? Int,
               (0...23).contains(hour), (0...59).contains(minute) {
                let rawWeekdays = ttDict["weekdays"] as? [Int] ?? [2, 3, 4, 5, 6]
                // LOW-3 修复：仅保留合法星期值 1...7
                let weekdays = Set(rawWeekdays.filter { (1...7).contains($0) })
                timeTrigger = TimeTrigger(hour: hour, minute: minute, weekdays: weekdays)
            }

            var idleTrigger: IdleTrigger?
            if let itDict = ruleDict["idleTrigger"] as? [String: Any],
               let idleMinutes = itDict["idleMinutes"] as? Int,
               (1...720).contains(idleMinutes) {
                let scopeRaw = itDict["scope"] as? String
                let scope = IdleScope(rawValue: scopeRaw ?? "app") ?? .app
                idleTrigger = IdleTrigger(idleMinutes: idleMinutes, scope: scope)
            }

            let rule = AppRule(
                appBundleID: bundleID,
                appName: appName,
                ruleType: ruleType,
                isEnabled: isEnabled,
                timeTrigger: timeTrigger,
                idleTrigger: idleTrigger
            )
            rule.profile = profile
            modelContext.insert(rule)
        }

        saveChanges()
        refreshProfiles()
        return profile
    }

    /// 触发导入流程（打开文件选择器）
    func beginImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = String(localized: "选择 AutoToggle 配置方案文件")

        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            _ = self?.importProfile(from: url)
        }
    }

    // MARK: - 内部方法

    /// 刷新方案列表
    func refreshProfiles() {
        let descriptor = FetchDescriptor<Profile>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        profiles = (try? modelContext.fetch(descriptor)) ?? []
        activeProfile = profiles.first { $0.isActive }
    }

    /// 构建导出的 JSON 数据
    private func buildExportData(for profile: Profile) -> [String: Any] {
        let rulesData = (profile.rules ?? []).map { rule -> [String: Any] in
            var dict: [String: Any] = [
                "appBundleID": rule.appBundleID,
                "appName": rule.appName,
                "ruleType": rule.ruleTypeRaw,
                "isEnabled": rule.isEnabled,
            ]

            if let tt = rule.timeTrigger {
                dict["timeTrigger"] = [
                    "hour": tt.hour,
                    "minute": tt.minute,
                    "weekdays": Array(tt.weekdays),
                ]
            }

            if let it = rule.idleTrigger {
                dict["idleTrigger"] = [
                    "idleMinutes": it.idleMinutes,
                    "scope": it.scope.rawValue,
                ]
            }

            return dict
        }

        return [
            "version": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "profileName": profile.name,
            "rules": rulesData,
        ]
    }

    private func saveChanges() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("保存配置方案失败: \(error.localizedDescription, privacy: .public)")
        }
    }
}
