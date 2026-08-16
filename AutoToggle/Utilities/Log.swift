import OSLog

/// 统一的开发者日志 facade。
/// 输出到 Console.app（os.Logger），与用户可见的应用内 Logs tab（SwiftData LogManager）分离。
/// 仅用于开发者诊断，不承载面向用户的语义化日志。
enum Log {
    static let appAction = Logger(subsystem: "com.autotoggle.app", category: "appAction")
    static let persistence = Logger(subsystem: "com.autotoggle.app", category: "persistence")
    static let schedule = Logger(subsystem: "com.autotoggle.app", category: "schedule")
    static let permission = Logger(subsystem: "com.autotoggle.app", category: "permission")
    static let general = Logger(subsystem: "com.autotoggle.app", category: "general")
}
