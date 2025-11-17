import Foundation

/// Manages Xcode Command Line Tools installation
class CommandLineToolsInstaller {
    /// Check if Xcode Command Line Tools are installed
    /// - Returns: True if installed
    static func isInstalled() -> Bool {
        // Check for CLTools package
        let result = try? ProcessExecutor.execute(
            ["/usr/sbin/pkgutil", "--pkgs"],
            captureOutput: true
        )

        guard let output = result?.stdout else {
            return false
        }

        return output.contains("com.apple.pkg.CLTools_Executables")
    }

    /// Get installed CLTools version
    /// - Returns: Version string or nil if not installed
    static func installedVersion() -> String? {
        guard isInstalled() else {
            return nil
        }

        let result = try? ProcessExecutor.execute(
            ["/usr/sbin/pkgutil", "--pkg-info", "com.apple.pkg.CLTools_Executables"],
            captureOutput: true
        )

        guard let output = result?.stdout else {
            return nil
        }

        // Parse version from output (format: "version: 15.0.0.0.1.1695320061")
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("version:") {
                let version = line.replacingOccurrences(of: "version:", with: "").trimmingCharacters(in: .whitespaces)
                return version
            }
        }

        return nil
    }

    /// Ensure Xcode Command Line Tools are installed
    /// - Throws: BrewmeisterError if installation fails
    static func ensureInstalled() throws {
        if isInstalled() {
            if let version = installedVersion() {
                Logger.info("Xcode Command Line Tools already installed (version \(version))")
            } else {
                Logger.info("Xcode Command Line Tools already installed")
            }
            return
        }

        Logger.info("Xcode Command Line Tools not found, installation required")
        Logger.warning("Please install Xcode Command Line Tools:")
        Logger.info("  Run: xcode-select --install")
        Logger.info("  Or install Xcode from the App Store")

        throw BrewmeisterError.commandLineToolsMissing
    }

    /// Check if xcode-select path is set
    /// - Returns: True if xcode-select has a valid path
    static func hasXcodeSelectPath() -> Bool {
        let result = try? ProcessExecutor.execute(
            ["/usr/bin/xcode-select", "-p"],
            captureOutput: true
        )

        return result?.succeeded ?? false
    }

    /// Get the xcode-select path
    /// - Returns: Path string or nil
    static func xcodeSelectPath() -> String? {
        let result = try? ProcessExecutor.execute(
            ["/usr/bin/xcode-select", "-p"],
            captureOutput: true
        )

        guard let output = result?.stdout, result?.succeeded == true else {
            return nil
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
