import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.optimizador.macm4"
    private static let general = Logger(subsystem: subsystem, category: "general")
    private static let security = Logger(subsystem: subsystem, category: "security")
    private static let monitor = Logger(subsystem: subsystem, category: "monitor")
    private static let processes = Logger(subsystem: subsystem, category: "processes")
    private static let cache = Logger(subsystem: subsystem, category: "cache")

    static func info(_ message: String, category: LogCategory = .general) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    static func error(_ message: String, category: LogCategory = .general) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    static func warning(_ message: String, category: LogCategory = .general) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    enum LogCategory {
        case general, security, monitor, processes, cache
    }

    private static func logger(for category: LogCategory) -> Logger {
        switch category {
        case .general: return general
        case .security: return security
        case .monitor: return monitor
        case .processes: return processes
        case .cache: return cache
        }
    }
}
