import Foundation

/// Manages sudo access and privileged operations
class PrivilegeManager {
    /// Shared instance
    static let shared = PrivilegeManager()

    private init() {}

    /// Check if current process has sudo access
    /// - Returns: True if sudo is available
    func ensureSudoAccess() throws -> Bool {
        Logger.debug("Checking sudo access")

        let hasSudo = ProcessExecutor.haveSudoAccess()

        if !hasSudo {
            Logger.error("Sudo access required but not available")
            throw BrewmeisterError.insufficientPrivileges
        }

        Logger.debug("Sudo access confirmed")
        return true
    }

    /// Configure passwordless sudo for a service account
    /// - Parameters:
    ///   - account: Service account to configure
    ///   - brewPrefix: Homebrew installation prefix (for scoped sudo)
    func configurePasswordlessSudo(
        for account: ServiceAccount,
        brewPrefix: String
    ) throws {
        Logger.info("Configuring passwordless sudo for \(account.username)")

        let sudoersPath = "/private/etc/sudoers.d/\(account.username)"

        // Create sudoers content
        // Scope to specific brew command for better security
        let sudoersContent = """
        # Brewmeister service account sudo configuration
        # Allow passwordless execution of brew for cask installations
        \(account.username) ALL = (ALL) NOPASSWD: \(brewPrefix)/bin/brew
        """

        // Write to temporary file first
        let tempPath = "/tmp/sudoers.\(UUID().uuidString)"

        do {
            try FileSystemManager.writeString(sudoersContent, to: tempPath, atomically: true)
        } catch {
            throw BrewmeisterError.invalidSudoersFile
        }

        // Validate with visudo
        Logger.debug("Validating sudoers syntax")
        let validateResult = try ProcessExecutor.execute(
            ["/usr/sbin/visudo", "-c", "-f", tempPath],
            captureOutput: true
        )

        guard validateResult.succeeded else {
            try? FileSystemManager.remove(tempPath)
            Logger.error("Sudoers validation failed: \(validateResult.stderr)")
            throw BrewmeisterError.invalidSudoersFile
        }

        // Install sudoers file with proper permissions using install command
        // This sets ownership and permissions atomically
        let installResult = try ProcessExecutor.execute(
            ["/usr/bin/install", "-o", "root", "-g", "wheel", "-m", "0440", tempPath, sudoersPath],
            captureOutput: true
        )

        // Clean up temp file
        try? FileSystemManager.remove(tempPath)

        guard installResult.succeeded else {
            Logger.error("Failed to install sudoers file: \(installResult.stderr)")
            throw BrewmeisterError.fileSystemError(
                underlying: NSError(
                    domain: "PrivilegeManager",
                    code: installResult.exitCode,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to install sudoers file"]
                )
            )
        }

        Logger.success("Configured passwordless sudo for \(account.username)")
        Logger.info("Sudoers file: \(sudoersPath)")
    }

    /// Remove passwordless sudo configuration
    /// - Parameter username: Username to remove configuration for
    func removePasswordlessSudo(for username: String) throws {
        let sudoersPath = "/private/etc/sudoers.d/\(username)"

        if FileSystemManager.exists(sudoersPath) {
            try FileSystemManager.remove(sudoersPath)
            Logger.info("Removed sudoers configuration for \(username)")
        }
    }

    /// Check if passwordless sudo is configured
    /// - Parameter username: Username to check
    /// - Returns: True if configured
    func hasPasswordlessSudo(for username: String) -> Bool {
        let sudoersPath = "/private/etc/sudoers.d/\(username)"
        return FileSystemManager.exists(sudoersPath)
    }
}
