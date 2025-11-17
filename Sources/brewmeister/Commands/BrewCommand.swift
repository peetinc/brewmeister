import ArgumentParser
import Foundation

/// Brew command - default subcommand that executes brew commands as service account
struct BrewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_default",
        abstract: "Execute brew command as service account (default passthrough)",
        shouldDisplay: false  // Hidden - this is the default command
    )

    @Argument(parsing: .captureForPassthrough, help: "Arguments to pass to brew")
    var brewArguments: [String] = []

    func run() throws {
        // Check if configured
        guard let config = Configuration.load() else {
            Logger.error("Brewmeister is not configured")
            Logger.info("Run 'sudo brewmeister setupmeister' first to configure the service account")
            throw BrewmeisterError.notConfigured(
                message: "Configuration not found"
            )
        }

        // Verify service account exists
        let accountExists = try ServiceAccountManager.accountExists(config.serviceAccount)
        guard accountExists else {
            Logger.error("Service account '\(config.serviceAccount)' not found")
            Logger.info("Run 'sudo brewmeister setupmeister' to create it")
            throw BrewmeisterError.serviceAccountNotFound(config.serviceAccount)
        }

        // If no arguments, show brew-style help
        if brewArguments.isEmpty {
            print("Example usage:")
            print("  brewmeister setupmeister")
            print("  brewmeister healthmeister [--repair] [--verbose]")
            print("  brewmeister removemeister [--dry-run] [--force]")
            print("")
            print("  brewmeister brew install FORMULA|CASK...")
            print("  brewmeister install FORMULA|CASK...        (same thing)")
            print("  brewmeister brew upgrade [FORMULA|CASK...]")
            print("  brewmeister upgrade [FORMULA|CASK...]     (same thing)")
            print("")
            print("Brewmeister management:")
            print("  setupmeister              Install brewmeister service account and Homebrew")
            print("  healthmeister             Validate brewmeister installation and repair issues")
            print("  removemeister             Remove brewmeister (and optionally Homebrew)")
            print("  brew [command]            Explicit Homebrew passthrough")
            print("")
            print("Troubleshooting:")
            print("  brewmeister healthmeister --repair")
            print("  brewmeister brew doctor")
            print("  brewmeister brew config")
            print("")
            print("Getting help:")
            print("  brewmeister --help                   # Show this message")
            print("  brewmeister -h                       # Short help flag")
            print("  brewmeister [COMMAND] --help         # Help for specific command")
            print("  man brew                             # Homebrew manual")
            print("  https://docs.brew.sh                 # Homebrew documentation")
            print("")
            print("Configuration:")
            print("  Service account: \(config.serviceAccount)")
            print("  Brew prefix: \(config.brewPrefix)")
            print("  Architecture: \(config.architecture.rawValue)")
            return
        }

        // Execute brew command
        Logger.debug("Executing: brew \(brewArguments.joined(separator: " "))")

        let result = try BrewExecutor.execute(
            arguments: brewArguments,
            asUser: config.serviceAccount,
            brewPrefix: config.brewPrefix,
            architecture: config.architecture,
            captureOutput: false  // Stream to terminal
        )

        // Exit with brew's exit code
        if !result.succeeded {
            throw ExitCode(Int32(result.exitCode))
        }
    }
}
