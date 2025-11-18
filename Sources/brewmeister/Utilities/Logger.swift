import Logging
import Foundation

/// Centralized logging for brewmeister
class Logger {
    /// Shared logger instance
    static var shared = Logger()

    /// The underlying logger
    private var logger: Logging.Logger

    /// Initialize the logger
    private init() {
        self.logger = Logging.Logger(label: "com.peetinc.brewmeister")

        // Configure log level from environment or default to info
        if let logLevel = ProcessInfo.processInfo.environment["BREWMEISTER_LOG_LEVEL"] {
            switch logLevel.lowercased() {
            case "trace": logger.logLevel = .trace
            case "debug": logger.logLevel = .debug
            case "info": logger.logLevel = .info
            case "notice": logger.logLevel = .notice
            case "warning": logger.logLevel = .warning
            case "error": logger.logLevel = .error
            case "critical": logger.logLevel = .critical
            default: logger.logLevel = .info
            }
        } else {
            logger.logLevel = .info
        }
    }

    // MARK: - Static Logging Methods

    /// Log a debug message
    static func debug(_ message: String, metadata: [String: String]? = nil) {
        var loggerMetadata: Logging.Logger.Metadata?
        if let metadata = metadata {
            loggerMetadata = metadata.mapValues { .string($0) }
        }
        shared.logger.debug("\(message)", metadata: loggerMetadata)
    }

    /// Log an info message
    static func info(_ message: String, metadata: [String: String]? = nil) {
        var loggerMetadata: Logging.Logger.Metadata?
        if let metadata = metadata {
            loggerMetadata = metadata.mapValues { .string($0) }
        }
        shared.logger.info("\(message)", metadata: loggerMetadata)
    }

    /// Log a warning message
    static func warning(_ message: String, metadata: [String: String]? = nil) {
        var loggerMetadata: Logging.Logger.Metadata?
        if let metadata = metadata {
            loggerMetadata = metadata.mapValues { .string($0) }
        }
        shared.logger.warning("\(message)", metadata: loggerMetadata)
    }

    /// Log an error message
    static func error(_ message: String, metadata: [String: String]? = nil) {
        var loggerMetadata: Logging.Logger.Metadata?
        if let metadata = metadata {
            loggerMetadata = metadata.mapValues { .string($0) }
        }
        shared.logger.error("\(message)", metadata: loggerMetadata)
    }

    /// Log a critical error message
    static func critical(_ message: String, metadata: [String: String]? = nil) {
        var loggerMetadata: Logging.Logger.Metadata?
        if let metadata = metadata {
            loggerMetadata = metadata.mapValues { .string($0) }
        }
        shared.logger.critical("\(message)", metadata: loggerMetadata)
    }

    /// Log a success message (info level with checkmark)
    static func success(_ message: String, metadata: [String: String]? = nil) {
        info("✓ \(message)", metadata: metadata)
    }

    /// Set the log level
    static func setLogLevel(_ level: Logging.Logger.Level) {
        shared.logger.logLevel = level
    }
}
