import Foundation
import IOKit
import CoreGraphics

/// 系统级闲置时间提供者
/// 返回「自上次键盘/鼠标输入以来」的秒数，用于全局闲置检测。
/// 该接口读取系统状态，无需任何 TCC 权限（辅助功能/输入监控均不需要）。
protocol SystemIdleProviding: Sendable {
    /// 当前系统闲置秒数；失败或未知时返回 0（视为「当前活跃」的安全默认）
    func systemIdleTime() -> TimeInterval
}

/// IOKit 实现：读取 IOHIDSystem 注册表服务的 HIDIdleTime 属性（纳秒，自上次 HID 输入）。
/// 依赖 GUI 会话（Aqua/console）；headless 环境无 IOHIDSystem 节点时会读取失败。
struct IOKitSystemIdleProvider: SystemIdleProviding {
    func systemIdleTime() -> TimeInterval {
        idleTimeOrNil() ?? 0
    }

    /// 返回秒级闲置时间；无法读取（无 IOHIDSystem 节点）时返回 nil。
    /// 供 Hybrid 区分「无节点」与「刚有输入」，避免把读取失败误判为活跃。
    func idleTimeOrNil() -> TimeInterval? {
        guard let nanos = Self.readHIDIdleTimeNanoseconds() else { return nil }
        return TimeInterval(nanos) / 1_000_000_000
    }

    /// 读取 HIDIdleTime（纳秒）；无 IOHIDSystem 节点时返回 nil
    static func readHIDIdleTimeNanoseconds() -> UInt64? {
        // IOServiceMatching 返回 +1 字典，被下面的调用消费，不要单独 release
        let matching = IOServiceMatching("IOHIDSystem")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        // "Create" 规则 → +1 引用 → takeRetainedValue（takeUnretainedValue 会泄漏）
        guard let cfValue = IORegistryEntryCreateCFProperty(
            service,
            "HIDIdleTime" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }

        // CFNumber 与 NSNumber 桥接；HIDIdleTime 为有符号 64 位纳秒，用 int64Value 读
        guard let number = cfValue as? NSNumber else { return nil }
        let nanos = number.int64Value
        guard nanos >= 0 else { return nil }
        return UInt64(nanos)
    }
}

/// CoreGraphics 实现：组合会话状态，跨键盘/鼠标/滚动取最小（最近一次输入）。
/// 无需权限，且不依赖 IOHIDSystem 节点，作为 IOKit 的兜底。
struct CGEventSourceSystemIdleProvider: SystemIdleProviding {
    func systemIdleTime() -> TimeInterval {
        let inputTypes: [CGEventType] = [
            .keyDown, .flagsChanged,                                      // 键盘 + 修饰键
            .leftMouseDown, .rightMouseDown, .otherMouseDown,              // 点击
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,     // 拖拽
            .scrollWheel, .mouseMoved,                                     // 滚动 + 指针
        ]
        let mostRecent = inputTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
        return max(0, mostRecent)
    }
}

/// 兜底选择：主源可用（非 nil）时采用，否则回退到备用源。
/// 纯函数，便于单元测试。
enum SystemIdleFallback {
    static func select(primary: TimeInterval?, fallback: TimeInterval) -> TimeInterval {
        if let primary { return primary }
        return fallback
    }
}

/// 混合实现：优先 IOKit（更权威），读取失败时回退到 CGEventSource。
struct HybridSystemIdleProvider: SystemIdleProviding {
    private let iokit: IOKitSystemIdleProvider
    private let fallback: CGEventSourceSystemIdleProvider

    init(
        iokit: IOKitSystemIdleProvider = IOKitSystemIdleProvider(),
        fallback: CGEventSourceSystemIdleProvider = CGEventSourceSystemIdleProvider()
    ) {
        self.iokit = iokit
        self.fallback = fallback
    }

    func systemIdleTime() -> TimeInterval {
        // 仅在 IOKit 成功读取（含 0 = 刚有输入）时采用；读取失败回退 CGEventSource
        SystemIdleFallback.select(
            primary: iokit.idleTimeOrNil(),
            fallback: fallback.systemIdleTime()
        )
    }
}
