import Foundation

/// Executes brew commands as the service account
class BrewExecutor {
    /// Execute a brew command as the service account
    /// - Parameters:
    ///   - arguments: Arguments to pass to brew (e.g., ["install", "jq"])
    ///   - username: Service account username
    ///   - brewPrefix: Homebrew installation prefix
    ///   - architecture: System architecture (for arch prefix)
    ///   - captureOutput: Whether to capture output or stream to terminal
    /// - Returns: Execution result
    static func execute(
        arguments: [String],
        asUser username: String,
        brewPrefix: String,
        architecture: Architecture,
        captureOutput: Bool = false
    ) throws -> ExecutionResult {
        let brewPath = "\(brewPrefix)/bin/brew"

        // Verify brew exists
        guard FileSystemManager.exists(brewPath) else {
            throw BrewmeisterError.homebrewInstallationFailed(
                reason: "brew not found at \(brewPath)"
            )
        }

        // Build command with architecture prefix if needed
        let command = architecture.archPrefix + [brewPath] + arguments

        Logger.debug("Executing: \(command.joined(separator: " "))")

        // Execute as service account with login shell
        // Set HOME to /var/brewmeister so Homebrew can create caches
        let result = try ProcessExecutor.executeAsUser(
            username: username,
            command: command,
            captureOutput: captureOutput,
            loginShell: true,
            homeDirectory: "/var/brewmeister"
        )

        return result
    }

    /// Execute a brew command using the current configuration
    /// - Parameters:
    ///   - arguments: Arguments to pass to brew
    ///   - captureOutput: Whether to capture output
    /// - Returns: Execution result
    static func executeWithConfig(
        arguments: [String],
        captureOutput: Bool = false
    ) throws -> ExecutionResult {
        guard let config = Configuration.load() else {
            throw BrewmeisterError.notConfigured(
                message: "No configuration found. Run 'brewmeister setupmeister' first."
            )
        }

        return try execute(
            arguments: arguments,
            asUser: config.serviceAccount,
            brewPrefix: config.brewPrefix,
            architecture: config.architecture,
            captureOutput: captureOutput
        )
    }

    /// Install packages
    /// - Parameters:
    ///   - packages: Package names to install
    ///   - config: Configuration (optional, loads if not provided)
    static func install(packages: [String], config: Configuration? = nil) throws {
        let configuration = config ?? Configuration.load()
        guard let configuration = configuration else {
            throw BrewmeisterError.notConfigured(
                message: "Run 'brewmeister setupmeister' first"
            )
        }

        Logger.info("Installing packages: \(packages.joined(separator: ", "))")

        let result = try execute(
            arguments: ["install"] + packages,
            asUser: configuration.serviceAccount,
            brewPrefix: configuration.brewPrefix,
            architecture: configuration.architecture,
            captureOutput: false
        )

        guard result.succeeded else {
            throw BrewmeisterError.brewExecutionFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }

    /// Upgrade packages
    /// - Parameter config: Configuration (optional)
    static func upgrade(config: Configuration? = nil) throws {
        let configuration = config ?? Configuration.load()
        guard let configuration = configuration else {
            throw BrewmeisterError.notConfigured(
                message: "Run 'brewmeister setupmeister' first"
            )
        }

        Logger.info("Upgrading packages...")

        let result = try execute(
            arguments: ["upgrade"],
            asUser: configuration.serviceAccount,
            brewPrefix: configuration.brewPrefix,
            architecture: configuration.architecture,
            captureOutput: false
        )

        guard result.succeeded else {
            throw BrewmeisterError.brewExecutionFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }

    /// List installed packages
    /// - Parameter config: Configuration (optional)
    /// - Returns: List of installed packages
    static func list(config: Configuration? = nil) throws -> [String] {
        let configuration = config ?? Configuration.load()
        guard let configuration = configuration else {
            throw BrewmeisterError.notConfigured(
                message: "Run 'brewmeister setupmeister' first"
            )
        }

        let result = try execute(
            arguments: ["list", "--versions"],
            asUser: configuration.serviceAccount,
            brewPrefix: configuration.brewPrefix,
            architecture: configuration.architecture,
            captureOutput: true
        )

        guard result.succeeded else {
            throw BrewmeisterError.brewExecutionFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return result.stdout
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }
}
