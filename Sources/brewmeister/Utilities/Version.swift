import Foundation

/// Version and bundle information for brewmeister
enum Version {
    static let version = "2.0.0"
    static let bundleIdentifier = "com.peetinc.brewmeister"
    static let bundleName = "brewmeister"
    static let copyright = "Copyright © 2025 Peet Inc. All rights reserved."

    /// Full version string
    static var fullVersion: String {
        return "\(bundleName) \(version)"
    }

    /// Generate Info.plist compatible dictionary
    static var infoPlist: [String: String] {
        return [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": bundleName,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": version,
            "NSHumanReadableCopyright": copyright
        ]
    }
}
