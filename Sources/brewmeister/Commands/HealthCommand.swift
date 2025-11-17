import ArgumentParser
import Foundation

/// Health check command - validates a brewmeister installation with optional auto-repair
struct HealthCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "healthmeister",
        abstract: "Validate brewmeister installation and repair issues"
    )

    @Flag(name: .long, help: "Automatically repair issues found")
    var repair: Bool = false

    @Flag(name: [.short, .long], help: "Enable verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Skip brew doctor check")
    var skipBrewDoctor: Bool = false

    func run() throws {
        // Enable debug logging if verbose
        if verbose {
            Logger.setLogLevel(.debug)
        }

        let state = HealthState()

        print("\n" + String(repeating: "=", count: 60))
        Logger.info("Brewmeister Health Check")
        if repair {
            Logger.info("Auto-repair enabled")
        }
        print(String(repeating: "=", count: 60) + "\n")

        // Run all health checks
        try checkConfiguration(state: state)
        try checkServiceAccount(state: state)
        try checkHomeDirectory(state: state)
        try checkZshrc(state: state)
        try checkPATH(state: state)
        try checkBrewmeisterBinary(state: state)
        try checkManPage(state: state)
        try checkSudoers(state: state)
        try checkHomebrewInstallation(state: state)

        if !skipBrewDoctor {
            try checkBrewDoctor(state: state)
        }

        try checkSystemRequirements(state: state)

        // Print summary
        print("\n" + String(repeating: "=", count: 60))
        printSummary(state: state)
        print(String(repeating: "=", count: 60) + "\n")

        // Exit with appropriate code
        if state.failureCount > 0 {
            throw ExitCode(1)
        }
    }

    // MARK: - Health Check Methods

    private func checkConfiguration(state: HealthState) throws {
        Logger.info("Checking configuration...")

        guard let config = Configuration.load() else {
            recordResult(
                name: "Configuration file",
                status: .failed,
                message: "Configuration not found at /private/var/db/brewmeister/config.json",
                state: state
            )
            return
        }

        recordResult(
            name: "Configuration file",
            status: .passed,
            message: "Service account: \(config.serviceAccount), Prefix: \(config.brewPrefix)",
            state: state
        )

        if verbose {
            Logger.debug("  Architecture: \(config.architecture.rawValue)")
            Logger.debug("  Version: \(config.version)")
        }
    }

    private func checkServiceAccount(state: HealthState) throws {
        Logger.info("Checking service account...")

        guard let config = Configuration.load() else {
            recordResult(
                name: "Service account",
                status: .skipped,
                message: "Configuration not found",
                state: state
            )
            return
        }

        do {
            let exists = try ServiceAccountManager.accountExists(config.serviceAccount)
            if exists {
                recordResult(
                    name: "Service account '\(config.serviceAccount)'",
                    status: .passed,
                    message: "Account exists and is accessible",
                    state: state
                )
            } else {
                recordResult(
                    name: "Service account '\(config.serviceAccount)'",
                    status: .failed,
                    message: "Account not found in directory services",
                    state: state
                )
            }
        } catch {
            recordResult(
                name: "Service account check",
                status: .failed,
                message: "Error checking account: \(error.localizedDescription)",
                state: state
            )
        }
    }

    private func checkHomeDirectory(state: HealthState) throws {
        Logger.info("Checking service account home directory...")

        guard let config = Configuration.load() else {
            recordResult(
                name: "Home directory",
                status: .skipped,
                message: "Configuration not found",
                state: state
            )
            return
        }

        let homeDir = "/var/brewmeister"

        if FileSystemManager.exists(homeDir) && FileSystemManager.isDirectory(homeDir) {
            recordResult(
                name: "Home directory (\(homeDir))",
                status: .passed,
                message: "Directory exists",
                state: state
            )

            if verbose {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: homeDir)
                    if let owner = attrs[.ownerAccountName] as? String {
                        Logger.debug("  Owner: \(owner)")
                    }
                    if let perms = attrs[.posixPermissions] as? Int {
                        Logger.debug("  Permissions: \(String(perms, radix: 8))")
                    }
                } catch {
                    Logger.debug("  (Could not read attributes)")
                }
            }
        } else {
            recordResult(
                name: "Home directory (\(homeDir))",
                status: .failed,
                message: "Directory does not exist",
                state: state
            )

            if repair {
                do {
                    Logger.info("Attempting to repair: creating home directory...")
                    try FileSystemManager.createDirectory(
                        at: homeDir,
                        owner: config.serviceAccount,
                        permissions: 0o755
                    )
                    recordResult(
                        name: "Home directory repair",
                        status: .repaired,
                        message: "Directory created successfully",
                        state: state
                    )
                } catch {
                    recordResult(
                        name: "Home directory repair",
                        status: .failed,
                        message: "Failed to create directory: \(error.localizedDescription)",
                        state: state
                    )
                }
            }
        }
    }

    private func checkZshrc(state: HealthState) throws {
        Logger.info("Checking .zshrc configuration...")

        guard let config = Configuration.load() else {
            recordResult(
                name: ".zshrc",
                status: .skipped,
                message: "Configuration not found",
                state: state
            )
            return
        }

        let homeDir = "/var/brewmeister"
        let zshrcPath = "\(homeDir)/.zshrc"

        if FileSystemManager.exists(zshrcPath) {
            do {
                let content = try FileSystemManager.readString(from: zshrcPath)
                if content.contains("brew shellenv") {
                    recordResult(
                        name: ".zshrc",
                        status: .passed,
                        message: "Properly configured with brew shellenv",
                        state: state
                    )
                } else {
                    recordResult(
                        name: ".zshrc",
                        status: .warning,
                        message: "File exists but may be missing brew shellenv",
                        state: state
                    )

                    if repair {
                        Logger.info("Attempting to repair: updating .zshrc...")
                        let zshrcContent = """
                        # Brewmeister Homebrew environment
                        eval "$(\(config.brewPrefix)/bin/brew shellenv)"
                        """
                        try FileSystemManager.writeString(zshrcContent, to: zshrcPath, atomically: true)
                        recordResult(
                            name: ".zshrc repair",
                            status: .repaired,
                            message: "File updated successfully",
                            state: state
                        )
                    }
                }
            } catch {
                recordResult(
                    name: ".zshrc",
                    status: .warning,
                    message: "Could not read file: \(error.localizedDescription)",
                    state: state
                )
            }
        } else {
            recordResult(
                name: ".zshrc",
                status: .failed,
                message: "File not found",
                state: state
            )

            if repair {
                do {
                    Logger.info("Attempting to repair: creating .zshrc...")
                    let zshrcContent = """
                    # Brewmeister Homebrew environment
                    eval "$(\(config.brewPrefix)/bin/brew shellenv)"
                    """
                    try FileSystemManager.writeString(zshrcContent, to: zshrcPath, atomically: true)
                    try FileSystemManager.changeOwnership(
                        path: zshrcPath,
                        owner: config.serviceAccount,
                        group: "admin"
                    )
                    try FileSystemManager.setPermissions(path: zshrcPath, permissions: 0o644)
                    recordResult(
                        name: ".zshrc repair",
                        status: .repaired,
                        message: "File created successfully",
                        state: state
                    )
                } catch {
                    recordResult(
                        name: ".zshrc repair",
                        status: .failed,
                        message: "Failed to create file: \(error.localizedDescription)",
                        state: state
                    )
                }
            }
        }
    }

    private func checkPATH(state: HealthState) throws {
        Logger.info("Checking PATH configuration...")

        guard let config = Configuration.load() else {
            recordResult(
                name: "PATH",
                status: .skipped,
                message: "Configuration not found",
                state: state
            )
            return
        }

        let pathsDir = "/etc/paths.d"
        let pathsFile = "\(pathsDir)/00-brewmeister"

        if FileSystemManager.exists(pathsFile) {
            do {
                let content = try FileSystemManager.readString(from: pathsFile)
                if content.contains(config.brewPrefix) {
                    recordResult(
                        name: "PATH configuration (\(pathsFile))",
                        status: .passed,
                        message: "Homebrew prefix correctly added to PATH",
                        state: state
                    )
                } else {
                    recordResult(
                        name: "PATH configuration",
                        status: .warning,
                        message: "File exists but may contain incorrect path",
                        state: state
                    )

                    if repair {
                        Logger.info("Attempting to repair: updating PATH configuration...")
                        let pathContent = """
                        \(config.brewPrefix)/bin
                        \(config.brewPrefix)/sbin
                        """
                        try FileSystemManager.writeString(pathContent, to: pathsFile, atomically: true)
                        try FileSystemManager.setPermissions(path: pathsFile, permissions: 0o644)
                        recordResult(
                            name: "PATH repair",
                            status: .repaired,
                            message: "Configuration updated successfully",
                            state: state
                        )
                    }
                }
            } catch {
                recordResult(
                    name: "PATH configuration",
                    status: .warning,
                    message: "Could not read file: \(error.localizedDescription)",
                    state: state
                )
            }
        } else {
            recordResult(
                name: "PATH configuration",
                status: .failed,
                message: "File not found: \(pathsFile)",
                state: state
            )

            if repair {
                do {
                    Logger.info("Attempting to repair: creating PATH configuration...")
                    if !FileSystemManager.exists(pathsDir) {
                        try FileSystemManager.createDirectory(at: pathsDir)
                    }
                    let pathContent = """
                    \(config.brewPrefix)/bin
                    \(config.brewPrefix)/sbin
                    """
                    try FileSystemManager.writeString(pathContent, to: pathsFile, atomically: true)
                    try FileSystemManager.setPermissions(path: pathsFile, permissions: 0o644)
                    recordResult(
                        name: "PATH repair",
                        status: .repaired,
                        message: "Configuration created successfully",
                        state: state
                    )
                } catch {
                    recordResult(
                        name: "PATH repair",
                        status: .failed,
                        message: "Failed to create configuration: \(error.localizedDescription)",
                        state: state
                    )
                }
            }
        }
    }

    private func checkSudoers(state: HealthState) throws {
        Logger.info("Checking sudo configuration...")

        guard let config = Configuration.load() else {
            recordResult(
                name: "Sudoers",
                status: .skipped,
                message: "Configuration not found",
                state: state
            )
            return
        }

        let sudoersFile = "/private/etc/sudoers.d/\(config.serviceAccount)"

        if FileSystemManager.exists(sudoersFile) {
            do {
                let content = try FileSystemManager.readString(from: sudoersFile)
                if content.contains(config.serviceAccount) {
                    recordResult(
                        name: "Sudoers configuration",
                        status: .passed,
                        message: "Passwordless sudo properly configured",
                        state: state
                    )
                } else {
                    recordResult(
                        name: "Sudoers configuration",
                        status: .warning,
                        message: "File exists but may contain incorrect configuration",
                        state: state
                    )
                }
            } catch {
                recordResult(
                    name: "Sudoers configuration",
                    status: .warning,
                    message: "Could not read file: \(error.localizedDescription)",
                    state: state
                )
            }
        } else {
            recordResult(
                name: "Sudoers configuration",
                status: .failed,
                message: "File not found: \(sudoersFile)",
                state: state
            )

            if repair {
                Logger.info("Attempting to repair: configuring passwordless sudo...")
                do {
                    try PrivilegeManager.shared.configurePasswordlessSudo(
                        for: ServiceAccount(
                            username: config.serviceAccount,
                            uid: 0,
                            gid: 0,
                            homeDirectory: "/var/brewmeister"
                        ),
                        brewPrefix: config.brewPrefix
                    )
                    recordResult(
                        name: "Sudoers repair",
                        status: .repaired,
                        message: "Passwordless sudo configured successfully",
                        state: state
                    )
                } catch {
                    recordResult(
                        name: "Sudoers repair",
                        status: .failed,
                        message: "Failed to configure sudo: \(error.localizedDescription)",
                        state: state
                    )
                }
            }
        }
    }

    private func checkHomebrewInstallation(state: HealthState) throws {
        Logger.info("Checking Homebrew installation...")

        guard let config = Configuration.load() else {
            recordResult(
                name: "Homebrew installation",
                status: .skipped,
                message: "Configuration not found",
                state: state
            )
            return
        }

        let brewPath = "\(config.brewPrefix)/bin/brew"

        if FileSystemManager.exists(brewPath) {
            recordResult(
                name: "Homebrew binary",
                status: .passed,
                message: "Found at \(brewPath)",
                state: state
            )

            // Try to get version
            do {
                let result = try ProcessExecutor.executeAsUser(
                    username: config.serviceAccount,
                    command: [brewPath, "--version"],
                    captureOutput: true,
                    loginShell: false,
                    homeDirectory: "/var/brewmeister"
                )

                if result.succeeded {
                    let versionOutput = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    Logger.info("Version: \(versionOutput)")
                } else {
                    recordResult(
                        name: "Homebrew version",
                        status: .warning,
                        message: "Could not retrieve version",
                        state: state
                    )
                }
            } catch {
                recordResult(
                    name: "Homebrew version",
                    status: .warning,
                    message: "Error executing brew: \(error.localizedDescription)",
                    state: state
                )
            }
        } else {
            recordResult(
                name: "Homebrew installation",
                status: .failed,
                message: "Homebrew not found at \(brewPath)",
                state: state
            )
        }
    }

    private func checkBrewDoctor(state: HealthState) throws {
        Logger.info("Running brew doctor...")

        guard let config = Configuration.load() else {
            recordResult(
                name: "Brew doctor",
                status: .skipped,
                message: "Configuration not found",
                state: state
            )
            return
        }

        let brewPath = "\(config.brewPrefix)/bin/brew"

        guard FileSystemManager.exists(brewPath) else {
            recordResult(
                name: "Brew doctor",
                status: .skipped,
                message: "Homebrew not installed",
                state: state
            )
            return
        }

        do {
            let result = try ProcessExecutor.executeAsUser(
                username: config.serviceAccount,
                command: [brewPath, "doctor"],
                captureOutput: true,
                loginShell: false,
                homeDirectory: "/var/brewmeister"
            )

            if result.succeeded {
                recordResult(
                    name: "Brew doctor",
                    status: .passed,
                    message: "No issues found",
                    state: state
                )
            } else {
                let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let output = !stderr.isEmpty ? stderr : stdout

                recordResult(
                    name: "Brew doctor",
                    status: .warning,
                    message: "Warnings or issues found",
                    state: state
                )

                if verbose && !output.isEmpty {
                    Logger.debug("Brew doctor output:")
                    Logger.debug(output)
                }
            }
        } catch {
            recordResult(
                name: "Brew doctor",
                status: .warning,
                message: "Could not run brew doctor: \(error.localizedDescription)",
                state: state
            )
        }
    }

    private func checkSystemRequirements(state: HealthState) throws {
        Logger.info("Checking system requirements...")

        // Check for Xcode Command Line Tools
        do {
            let result = try ProcessExecutor.execute(
                ["/usr/bin/xcode-select", "-p"],
                captureOutput: true
            )

            if result.succeeded {
                let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                recordResult(
                    name: "Xcode Command Line Tools",
                    status: .passed,
                    message: "Found at \(path)",
                    state: state
                )
            } else {
                recordResult(
                    name: "Xcode Command Line Tools",
                    status: .failed,
                    message: "Not installed",
                    state: state
                )
            }
        } catch {
            recordResult(
                name: "Xcode Command Line Tools",
                status: .warning,
                message: "Could not check: \(error.localizedDescription)",
                state: state
            )
        }

        // Check for git
        do {
            let result = try ProcessExecutor.execute(
                ["/usr/bin/which", "git"],
                captureOutput: true
            )

            if result.succeeded {
                recordResult(
                    name: "Git",
                    status: .passed,
                    message: "Found and available",
                    state: state
                )
            } else {
                recordResult(
                    name: "Git",
                    status: .warning,
                    message: "Not found in PATH",
                    state: state
                )
            }
        } catch {
            recordResult(
                name: "Git",
                status: .warning,
                message: "Could not check: \(error.localizedDescription)",
                state: state
            )
        }
    }

    private func checkBrewmeisterBinary(state: HealthState) throws {
        Logger.info("Checking brewmeister binary installation...")

        let binaryPath = "/usr/local/bin/brewmeister"

        if FileSystemManager.exists(binaryPath) {
            // Check if it's executable
            do {
                let result = try ProcessExecutor.execute(
                    ["/bin/ls", "-l", binaryPath],
                    captureOutput: true
                )

                if result.stdout.contains("x") {
                    recordResult(
                        name: "Brewmeister binary",
                        status: .passed,
                        message: "Installed at \(binaryPath)",
                        state: state
                    )
                } else {
                    recordResult(
                        name: "Brewmeister binary",
                        status: .warning,
                        message: "Found but not executable",
                        state: state
                    )

                    if repair {
                        Logger.info("Attempting to repair: setting executable permissions...")
                        do {
                            try FileSystemManager.setPermissions(path: binaryPath, permissions: 0o755)
                            recordResult(
                                name: "Binary repair",
                                status: .repaired,
                                message: "Set executable permissions",
                                state: state
                            )
                        } catch {
                            recordResult(
                                name: "Binary repair",
                                status: .failed,
                                message: "Could not set permissions: \(error.localizedDescription)",
                                state: state
                            )
                        }
                    }
                }
            } catch {
                recordResult(
                    name: "Brewmeister binary",
                    status: .warning,
                    message: "Could not check permissions: \(error.localizedDescription)",
                    state: state
                )
            }
        } else {
            recordResult(
                name: "Brewmeister binary",
                status: .failed,
                message: "Not found at \(binaryPath)",
                state: state
            )

            if repair {
                Logger.info("Attempting to repair: installing brewmeister binary...")

                do {
                    // Get current executable path
                    let executablePath = CommandLine.arguments[0]

                    // Ensure /usr/local/bin exists
                    if !FileSystemManager.exists("/usr/local/bin") {
                        try FileSystemManager.createDirectory(at: "/usr/local/bin", withIntermediateDirectories: true)
                    }

                    // Copy brewmeister binary
                    let copyResult = try ProcessExecutor.execute([
                        "/bin/cp", executablePath, binaryPath
                    ], captureOutput: true)

                    if copyResult.succeeded {
                        // Set executable permissions
                        try FileSystemManager.setPermissions(path: binaryPath, permissions: 0o755)
                        recordResult(
                            name: "Binary repair",
                            status: .repaired,
                            message: "Installed to \(binaryPath)",
                            state: state
                        )
                    } else {
                        recordResult(
                            name: "Binary repair",
                            status: .failed,
                            message: "Could not copy binary",
                            state: state
                        )
                    }
                } catch {
                    recordResult(
                        name: "Binary repair",
                        status: .failed,
                        message: "Installation failed: \(error.localizedDescription)",
                        state: state
                    )
                }
            }
        }
    }

    private func checkManPage(state: HealthState) throws {
        Logger.info("Checking brewmeister man page...")

        let manPagePath = "/usr/local/share/man/man1/brewmeister.1"

        if FileSystemManager.exists(manPagePath) {
            recordResult(
                name: "Man page",
                status: .passed,
                message: "Installed at \(manPagePath)",
                state: state
            )
        } else {
            recordResult(
                name: "Man page",
                status: .warning,
                message: "Not found at \(manPagePath)",
                state: state
            )

            if repair {
                Logger.info("Attempting to repair: installing man page...")

                do {
                    // Get current executable path and derive project root
                    let executablePath = CommandLine.arguments[0]
                    let executableURL = URL(fileURLWithPath: executablePath)
                    let projectRoot = executableURL.deletingLastPathComponent()
                        .deletingLastPathComponent()
                        .deletingLastPathComponent()
                    let manPageSource = projectRoot.appendingPathComponent("man/brewmeister.1").path

                    if FileSystemManager.exists(manPageSource) {
                        // Create man directory if needed
                        let manDir = "/usr/local/share/man/man1"
                        if !FileSystemManager.exists(manDir) {
                            try FileSystemManager.createDirectory(at: manDir, withIntermediateDirectories: true)
                        }

                        // Copy man page
                        let copyResult = try ProcessExecutor.execute([
                            "/bin/cp", manPageSource, manPagePath
                        ], captureOutput: true)

                        if copyResult.succeeded {
                            try FileSystemManager.setPermissions(path: manPagePath, permissions: 0o644)
                            recordResult(
                                name: "Man page repair",
                                status: .repaired,
                                message: "Installed to \(manPagePath)",
                                state: state
                            )
                        } else {
                            recordResult(
                                name: "Man page repair",
                                status: .failed,
                                message: "Could not copy man page",
                                state: state
                            )
                        }
                    } else {
                        recordResult(
                            name: "Man page repair",
                            status: .failed,
                            message: "Man page source not found at \(manPageSource)",
                            state: state
                        )
                    }
                } catch {
                    recordResult(
                        name: "Man page repair",
                        status: .failed,
                        message: "Installation failed: \(error.localizedDescription)",
                        state: state
                    )
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func recordResult(
        name: String,
        status: CheckStatus,
        message: String,
        state: HealthState
    ) {
        state.recordResult(name: name, status: status, message: message)

        let symbol: String
        switch status {
        case .passed:
            symbol = "✓"
        case .warning:
            symbol = "⚠"
        case .failed:
            symbol = "✗"
        case .skipped:
            symbol = "○"
        case .repaired:
            symbol = "🔧"
        }

        print("[\(symbol)] \(name): \(message)")
    }

    private func printSummary(state: HealthState) {
        print("\nHealth Check Results:")
        print("  Passed:   \(state.passedCount)")
        print("  Warnings: \(state.warningCount)")
        print("  Failed:   \(state.failureCount)")
        print("  Skipped:  \(state.skippedCount)")
        print("  Repaired: \(state.repairedCount)")

        if state.failureCount > 0 {
            Logger.error("Health check FAILED - \(state.failureCount) issue(s) found")
            if !repair {
                Logger.info("Run with --repair to attempt automatic fixes")
            }
        } else if state.warningCount > 0 {
            Logger.warning("Health check completed with \(state.warningCount) warning(s)")
        } else {
            Logger.success("Health check passed!")
        }
    }
}

// MARK: - HealthState

/// Mutable state holder for health check results
class HealthState {
    private(set) var results: [(name: String, status: CheckStatus, message: String)] = []
    private(set) var passedCount = 0
    private(set) var warningCount = 0
    private(set) var failureCount = 0
    private(set) var skippedCount = 0
    private(set) var repairedCount = 0

    /// Record a health check result
    func recordResult(name: String, status: CheckStatus, message: String) {
        results.append((name, status, message))

        switch status {
        case .passed:
            passedCount += 1
        case .warning:
            warningCount += 1
        case .failed:
            failureCount += 1
        case .skipped:
            skippedCount += 1
        case .repaired:
            repairedCount += 1
        }
    }
}

// MARK: - CheckStatus

/// Status of a health check
enum CheckStatus {
    case passed
    case warning
    case failed
    case skipped
    case repaired
}
