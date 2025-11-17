import ArgumentParser
import Foundation

/// Brew passthrough command - explicitly executes brew commands as service account
struct BrewPassthroughCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "brew",
        abstract: "Execute brew command as service account (explicit syntax)"
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

        // If no arguments, show help about brew passthrough
        if brewArguments.isEmpty {
            print("brewmeister brew - Execute Homebrew commands as service account")
            print("")
            print("USAGE: brewmeister brew <brew-command> [arguments...]")
            print("")
            print("EXAMPLES:")
            print("  brewmeister brew install jq")
            print("  brewmeister brew install -f python")
            print("  brewmeister brew upgrade")
            print("  brewmeister brew upgrade --dry-run")
            print("  brewmeister brew uninstall wget")
            print("  brewmeister brew list")
            print("  brewmeister brew search python")
            print("  brewmeister brew info jq")
            print("  brewmeister brew doctor")
            print("  brewmeister brew config")
            print("")
            print("All arguments after 'brew' are passed directly to Homebrew.")
            print("See 'man brew' or https://docs.brew.sh for brew command documentation.")
            print("")
            print("ALTERNATIVE SYNTAX:")
            print("  You can also use the shorter form without 'brew':")
            print("    brewmeister install jq")
            print("    brewmeister upgrade")
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
