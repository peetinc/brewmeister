import Foundation

/// Manages Homebrew installation
class HomebrewInstaller {
    /// Install Homebrew to a custom location
    /// - Parameters:
    ///   - prefix: Installation directory (e.g., "/opt/brewmeister")
    ///   - account: Service account that will own Homebrew
    /// - Throws: BrewmeisterError if installation fails
    static func install(toPath prefix: String, ownedBy account: ServiceAccount) throws {
        Logger.info("Installing Homebrew to \(prefix)")

        // Check if already installed
        let brewPath = "\(prefix)/bin/brew"
        if FileSystemManager.exists(brewPath) {
            Logger.info("Homebrew already exists at \(prefix)")
            Logger.info("Running brew update instead...")
            try update(at: prefix, asUser: account.username)
            return
        }

        // Create installation directory
        if !FileSystemManager.exists(prefix) {
            Logger.debug("Creating installation directory: \(prefix)")
            try FileSystemManager.createDirectory(
                at: prefix,
                owner: account.username,
                group: "admin",
                permissions: 0o755,
                withIntermediateDirectories: true
            )
        }

        // Download Homebrew tarball
        Logger.info("Downloading Homebrew from GitHub...")
        let tarballURL = "https://github.com/Homebrew/brew/tarball/master"
        let tarballPath = "/tmp/homebrew-\(UUID().uuidString).tar.gz"

        Logger.debug("Executing: /usr/bin/curl -fsSL -o \(tarballPath) \(tarballURL)")

        let curlResult = try ProcessExecutor.execute(
            ["/usr/bin/curl", "-fsSL", "-o", tarballPath, tarballURL],
            captureOutput: false  // Stream progress to terminal
        )

        Logger.debug("curl completed with exit code: \(curlResult.exitCode)")

        guard curlResult.succeeded else {
            Logger.error("Failed to download Homebrew")
            throw BrewmeisterError.homebrewInstallationFailed(reason: "Download failed with exit code \(curlResult.exitCode)")
        }

        // Verify file was downloaded
        guard FileSystemManager.exists(tarballPath) else {
            throw BrewmeisterError.homebrewInstallationFailed(reason: "Tarball not found after download")
        }

        Logger.info("Extracting Homebrew...")
        Logger.debug("Executing: /usr/bin/tar xzf \(tarballPath) --strip 1 -C \(prefix)")

        // Extract tarball
        let tarResult = try ProcessExecutor.execute(
            ["/usr/bin/tar", "xzf", tarballPath, "--strip", "1", "-C", prefix],
            captureOutput: false  // Stream to terminal
        )

        // Clean up tarball
        try? FileSystemManager.remove(tarballPath)

        guard tarResult.succeeded else {
            throw BrewmeisterError.homebrewInstallationFailed(
                reason: "Extraction failed with exit code \(tarResult.exitCode)"
            )
        }

        // Set ownership
        Logger.debug("Setting ownership to \(account.username):admin")
        try FileSystemManager.changeOwnership(
            path: prefix,
            owner: account.username,
            group: "admin",
            recursive: true
        )

        // Verify installation
        guard FileSystemManager.exists(brewPath) else {
            throw BrewmeisterError.homebrewInstallationFailed(
                reason: "brew binary not found after installation"
            )
        }

        Logger.success("Homebrew installed to \(prefix)")

        // Run initial update
        Logger.info("Running initial Homebrew update...")
        try update(at: prefix, asUser: account.username)
    }

    /// Update Homebrew at a specific location
    /// - Parameters:
    ///   - prefix: Homebrew installation prefix
    ///   - username: Username to run update as
    private static func update(at prefix: String, asUser username: String) throws {
        let brewPath = "\(prefix)/bin/brew"

        guard FileSystemManager.exists(brewPath) else {
            throw BrewmeisterError.homebrewInstallationFailed(
                reason: "brew not found at \(brewPath)"
            )
        }

        // Run brew update as service account
        let arch = SystemInfo.architecture
        let command = arch.archPrefix + [brewPath, "update", "--auto-update"]

        let result = try ProcessExecutor.executeAsUser(
            username: username,
            command: command,
            captureOutput: false,
            loginShell: true,
            homeDirectory: "/var/brewmeister"
        )

        if result.succeeded {
            Logger.success("Homebrew update complete")
        } else {
            Logger.warning("Homebrew update returned exit code \(result.exitCode)")
            // Don't fail on update errors, just log them
        }
    }

    /// Run brew doctor to check installation
    /// - Parameters:
    ///   - prefix: Homebrew installation prefix
    ///   - username: Username to run as
    static func doctor(at prefix: String, asUser username: String) throws {
        Logger.info("Running brew doctor...")

        let brewPath = "\(prefix)/bin/brew"
        let arch = SystemInfo.architecture
        let command = arch.archPrefix + [brewPath, "doctor"]

        let result = try ProcessExecutor.executeAsUser(
            username: username,
            command: command,
            captureOutput: false,
            loginShell: true,
            homeDirectory: "/var/brewmeister"
        )

        if result.succeeded {
            Logger.success("Brew doctor completed successfully")
        } else {
            Logger.warning("Brew doctor found issues (exit code: \(result.exitCode))")
        }
    }

    /// Check if Homebrew is installed at a location
    /// - Parameter prefix: Installation prefix to check
    /// - Returns: True if brew binary exists
    static func isInstalled(at prefix: String) -> Bool {
        let brewPath = "\(prefix)/bin/brew"
        return FileSystemManager.exists(brewPath)
    }

    /// Get Homebrew version
    /// - Parameters:
    ///   - prefix: Homebrew installation prefix
    ///   - username: Username to run as
    /// - Returns: Version string or nil
    static func version(at prefix: String, asUser username: String) -> String? {
        let brewPath = "\(prefix)/bin/brew"
        let arch = SystemInfo.architecture
        let command = arch.archPrefix + [brewPath, "--version"]

        guard let result = try? ProcessExecutor.executeAsUser(
            username: username,
            command: command,
            captureOutput: true,
            loginShell: true,
            homeDirectory: "/var/brewmeister"
        ), result.succeeded else {
            return nil
        }

        // Parse first line (e.g., "Homebrew 4.0.0")
        let firstLine = result.stdout.components(separatedBy: .newlines).first ?? ""
        return firstLine.trimmingCharacters(in: .whitespaces)
    }
}
