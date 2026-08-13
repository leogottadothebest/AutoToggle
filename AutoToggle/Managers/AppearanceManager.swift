import SwiftUI
import AppKit
import Combine

/// 外观管理器
/// 管理应用的浅色/深色/跟随系统三种模式，订阅系统外观变化并实时响应
@MainActor
@Observable
final class AppearanceManager {
    // MARK: - 公开属性

    /// 用户选择的模式（持久化到 UserDefaults）
    var selectedMode: AppearanceMode {
        didSet {
            guard oldValue != selectedMode else { return }
            applyMode()
            UserDefaults.standard.set(selectedMode.rawValue, forKey: "appAppearance")
        }
    }

    /// 当前生效的实际 ColorScheme（.light 或 .dark，从不为 nil）
    private(set) var effectiveColorScheme: ColorScheme = .light

    // MARK: - 模式枚举

    enum AppearanceMode: String, CaseIterable {
        case system
        case light
        case dark
    }

    // MARK: - Combine 订阅

    private var cancellables = Set<AnyCancellable>()
    private var isSubscribed = false

    // MARK: - 初始化

    init() {
        let stored = UserDefaults.standard.string(forKey: "appAppearance") ?? "system"
        let mode = AppearanceMode(rawValue: stored) ?? .system
        // 直接设置存储属性（绕过 didSet，避免初始化时访问 NSApp）
        selectedMode = mode
        // 初始化时不调用 applyMode()（NSApp 尚未就绪），仅从模式推导初始值
        effectiveColorScheme = Self.initialScheme(for: mode)
    }

    /// 应用启动后调用，激活系统外观检测和订阅
    func activate() {
        applyMode()
        subscribeToSystemAppearance()
    }

    // MARK: - 应用模式

    func applyMode() {
        switch selectedMode {
        case .light:
            effectiveColorScheme = .light
        case .dark:
            effectiveColorScheme = .dark
        case .system:
            effectiveColorScheme = Self.currentSystemColorScheme
        }
    }

    /// 从模式推导初始 ColorScheme（不使用 NSApp，安全用于 init）
    private static func initialScheme(for mode: AppearanceMode) -> ColorScheme {
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system:
            // init 阶段无法访问 NSApp，默认使用浅色
            // activate() 会在应用启动后立即校准
            return .light
        }
    }

    /// 检测当前系统外观（浅色/深色）—— 仅在 NSApp 就绪后调用
    static var currentSystemColorScheme: ColorScheme {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }

    // MARK: - 系统外观变化订阅

    private func subscribeToSystemAppearance() {
        guard !isSubscribed else { return }
        isSubscribed = true
        NSApp.publisher(for: \.effectiveAppearance)
            .map { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDark in
                guard let self, self.selectedMode == .system else { return }
                self.effectiveColorScheme = isDark ? .dark : .light
            }
            .store(in: &cancellables)
    }
}
