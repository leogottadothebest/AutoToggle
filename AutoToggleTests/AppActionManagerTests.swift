import Testing
import AppKit
@testable import AutoToggle

/// 假的运行应用快照，记录 terminate/forceTerminate 调用
@MainActor
final class FakeRunningApp: RunningAppDescriptor {
    var processIdentifier: pid_t
    var localizedName: String?
    var isTerminated: Bool
    var terminateCalls = 0
    var forceTerminateCalls = 0
    var onTerminate: (() -> Void)?
    var onForceTerminate: (() -> Void)?

    init(pid: pid_t, name: String? = nil, isTerminated: Bool = false) {
        self.processIdentifier = pid
        self.localizedName = name
        self.isTerminated = isTerminated
    }

    func terminate() -> Bool { terminateCalls += 1; onTerminate?(); return true }
    func forceTerminate() -> Bool { forceTerminateCalls += 1; onForceTerminate?(); return true }
    func activate(options: NSApplication.ActivationOptions) -> Bool { true }
}

/// 假的应用控制器，记录所有系统调用
@MainActor
final class FakeAppController: AppControlling {
    var runningAppHandler: ((String) -> (any RunningAppDescriptor)?)?
    var scriptResult: (success: Bool, error: String?) = (false, "fake failure")
    var executedScripts: [String] = []
    var openedURLs: [URL] = []
    var urlsByBundleID: [String: URL] = [:]
    var terminateCount = 0
    var forceTerminateCount = 0

    func makeApp(pid: pid_t, name: String? = nil) -> FakeRunningApp {
        let app = FakeRunningApp(pid: pid, name: name)
        app.onTerminate = { [weak self] in self?.terminateCount += 1 }
        app.onForceTerminate = { [weak self] in self?.forceTerminateCount += 1 }
        return app
    }

    func runningApp(bundleID: String) -> (any RunningAppDescriptor)? {
        runningAppHandler?(bundleID)
    }

    func urlForApplication(bundleID: String) -> URL? {
        urlsByBundleID[bundleID]
    }

    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completion: @escaping (NSRunningApplication?, Error?) -> Void
    ) {
        openedURLs.append(url)
        completion(nil, nil)
    }

    func executeAppleScript(_ source: String) -> (success: Bool, error: String?) {
        executedScripts.append(source)
        return scriptResult
    }
}

/// AppActionManager 三级退出回退与 PID 复用护栏测试
@Suite
struct AppActionManagerTests {
    @Test("非法 Bundle ID 在任何系统调用前被拒绝")
    @MainActor
    func invalidBundleIDIsRejected() {
        let controller = FakeAppController()
        controller.runningAppHandler = { _ in controller.makeApp(pid: 100) }
        let manager = AppActionManager()
        manager.configure(controller: controller)

        manager.terminateApp(bundleID: "com.apple; rm -rf", strategy: .force)

        #expect(controller.executedScripts.isEmpty)
        #expect(controller.terminateCount == 0)
        #expect(controller.forceTerminateCount == 0)
    }

    @Test("应用未运行则直接返回")
    @MainActor
    func notRunningAppReturnsEarly() {
        let controller = FakeAppController()
        controller.runningAppHandler = { _ in nil }
        let manager = AppActionManager()
        manager.configure(controller: controller)

        manager.terminateApp(bundleID: "com.apple.Safari", strategy: .force)

        #expect(controller.executedScripts.isEmpty)
        #expect(controller.terminateCount == 0)
    }

    @Test("AppleScript 优雅退出成功即止，不再降级")
    @MainActor
    func appleScriptSuccessStops() {
        let controller = FakeAppController()
        controller.scriptResult = (success: true, error: nil)
        controller.runningAppHandler = { _ in controller.makeApp(pid: 100) }
        let manager = AppActionManager()
        manager.configure(controller: controller)

        manager.terminateApp(bundleID: "com.apple.Safari", strategy: .force)

        #expect(controller.terminateCount == 0)
        #expect(controller.forceTerminateCount == 0)
    }

    @Test("普通退出策略：AppleScript 失败即停止，不降级")
    @MainActor
    func normalStrategyFailureStops() {
        let controller = FakeAppController()
        controller.scriptResult = (success: false, error: "not scriptable")
        controller.runningAppHandler = { _ in controller.makeApp(pid: 100) }
        let manager = AppActionManager()
        manager.configure(controller: controller)

        manager.terminateApp(bundleID: "com.apple.Safari", strategy: .normal)

        #expect(controller.terminateCount == 0)
        #expect(controller.forceTerminateCount == 0)
    }

    @Test("强制退出策略：AppleScript 失败后走 terminate 第二级")
    @MainActor
    func forceStrategyCallsTerminate() {
        let controller = FakeAppController()
        controller.scriptResult = (success: false, error: "not scriptable")
        controller.runningAppHandler = { _ in controller.makeApp(pid: 100) }
        let manager = AppActionManager()
        manager.configure(controller: controller)

        manager.terminateApp(bundleID: "com.apple.Safari", strategy: .force)

        #expect(controller.terminateCount == 1)
        #expect(controller.forceTerminateCount == 0) // 第三级在 3 秒后异步执行，此处不等待
    }

    @Test("PID 被复用（重查不一致）时跳过 terminate，避免误杀无关进程")
    @MainActor
    func forceStrategySkipsTerminateWhenPIDChanged() {
        let controller = FakeAppController()
        controller.scriptResult = (success: false, error: "not scriptable")
        var calls = 0
        controller.runningAppHandler = { _ in
            calls += 1
            return controller.makeApp(pid: calls == 1 ? 100 : 999)
        }
        let manager = AppActionManager()
        manager.configure(controller: controller)

        manager.terminateApp(bundleID: "com.apple.Safari", strategy: .force)

        #expect(controller.terminateCount == 0)
        #expect(controller.forceTerminateCount == 0)
    }
}
