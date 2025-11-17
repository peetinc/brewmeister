import Foundation

/// Represents the CPU architecture of the system
enum Architecture: String, Codable {
    case arm64
    case x86_64

    /// The current system architecture (compile-time detection)
    static var current: Architecture {
        #if arch(arm64)
        return .arm64
        #else
        return .x86_64
        #endif
    }

    /// Whether this architecture requires the arch wrapper command
    var requiresArchPrefix: Bool {
        return self == .arm64
    }

    /// The arch command prefix if needed (e.g., ["arch", "-arm64"])
    var archPrefix: [String] {
        return requiresArchPrefix ? ["arch", "-\(rawValue)"] : []
    }
}
