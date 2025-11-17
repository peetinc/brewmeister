import Foundation

/// System information utilities
class SystemInfo {
    /// The current system architecture
    static var architecture: Architecture {
        return Architecture.current
    }

    /// The operating system version string
    static var osVersion: String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    /// The detailed operating system version
    static var macOSVersion: OperatingSystemVersion {
        return ProcessInfo.processInfo.operatingSystemVersion
    }

    /// The machine hardware name (e.g., "arm64", "x86_64")
    static var machineHardwareName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// Check if running on Apple Silicon
    static var isAppleSilicon: Bool {
        return architecture == .arm64
    }

    /// Check if running as root
    static var isRoot: Bool {
        return getuid() == 0
    }

    /// Current user's username
    static var currentUsername: String {
        return ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
    }

    /// Current user's home directory
    static var currentUserHome: String {
        return ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
    }
}
