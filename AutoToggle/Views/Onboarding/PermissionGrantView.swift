import SwiftUI
import AppKit

/// 首次启动权限引导视图
/// 引导用户授予辅助功能权限以启用更精确的闲置检测（可选；核心闲置检测无需任何权限）
struct PermissionGrantView: View {
    /// 完成引导后的回调
    let onDismiss: () -> Void

    @Environment(PermissionManager.self) private var permissionManager

    /// 定时轮询权限状态的 Timer（用户前往系统设置后回来自动刷新）
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            // 图标
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .padding(.top, 20)

            // 标题
            Text("欢迎使用 AutoToggle")
                .font(.title)
                .fontWeight(.bold)

            // 说明
            VStack(alignment: .leading, spacing: 12) {
                Text("AutoToggle 通常无需额外权限，以下两项按需授权：")
                    .font(.body)
                    .foregroundStyle(.secondary)

                permissionRow(
                    icon: "accessibility",
                    title: "辅助功能权限（可选）",
                    description: "用于实时跟踪键盘焦点，提升应用闲置判断精度。核心闲置检测无需任何权限。",
                    granted: permissionManager.accessibilityGranted
                )

                permissionRow(
                    icon: "gearshape.2",
                    title: "自动化权限",
                    description: "用于自动退出和隐藏应用。首次触发时系统会弹出授权提示，按需授予。",
                    granted: nil
                )
            }
            .padding(.horizontal)

            Spacer()

            // 操作按钮
            VStack(spacing: 12) {
                if !permissionManager.accessibilityGranted {
                    Button("打开系统设置") {
                        permissionManager.openAccessibilitySettings()
                        startCheckingPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if permissionManager.needsRestartToApplyAccessibility {
                    VStack(spacing: 8) {
                        Label("若你已在系统设置中开启授权，重启应用后即可生效。",
                              systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("立即重启") {
                            permissionManager.restartToApplyAccessibility()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                Button(permissionManager.accessibilityGranted ? "开始使用" : "跳过，稍后设置") {
                    stopCheckingPermission()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .controlSize(.large)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 480, height: 440)
        .onAppear {
            // 面板重新打开时立即重新查询授权状态（此前靠轮询，面板关闭后轮询被停导致读到过期值）
            permissionManager.refresh()
        }
        .onDisappear {
            stopCheckingPermission()
        }
    }

    // MARK: - 权限行视图

    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        granted: Bool?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(statusColor(granted))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    statusLabel(granted)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// 权限状态颜色：已授权=绿，待授权=橙，按需授权=次要色
    private func statusColor(_ granted: Bool?) -> Color {
        switch granted {
        case .some(true): return .green
        case .some(false): return .orange
        case .none: return .secondary
        }
    }

    @ViewBuilder
    private func statusLabel(_ granted: Bool?) -> some View {
        switch granted {
        case .some(true):
            Label("已授权", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .some(false):
            Label("待授权", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .none:
            Label("按需授权", systemImage: "arrow.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 权限轮询

    /// 开始轮询权限状态（用户打开系统设置后）
    private func startCheckingPermission() {
        // 先停掉已有的轮询，避免重复点击「打开系统设置」时叠加多个 Timer
        stopCheckingPermission()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                permissionManager.refresh()
                if permissionManager.accessibilityGranted {
                    stopCheckingPermission()
                }
            }
        }
    }

    /// 停止轮询
    private func stopCheckingPermission() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
