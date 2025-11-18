import ArgumentParser
import Foundation

struct BrewmeisterCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: Version.bundleName,
        abstract: "Homebrew automation wrapper that enables root-level RMM tools to manage packages via dedicated service account",
        discussion: """
            PRIVILEGES:
              All brewmeister commands require root privileges (sudo).
              Only --help and --version can be run without sudo.

            OUTPUT CONTROL:
              --quiet   Only show errors
              --silent  No output at all

            USAGE:
              sudo brewmeister setupmeister      # Install brewmeister
              sudo brewmeister install <package> # Install packages
              sudo brewmeister usermeister       # Enable current user
              sudo brewmeister --quiet install jq # Quiet mode
            """,
        version: Version.version,
        subcommands: [SetupCommand.self, BrewPassthroughCommand.self, BrewCommand.self, HealthCommand.self, UninstallCommand.self, UsermeisterCommand.self],
        defaultSubcommand: BrewCommand.self,
        helpNames: [.short, .long]
    )
}

// Check if this is a help or version request
let args = CommandLine.arguments
let isHelpRequest = args.contains("--help") || args.contains("-h") || args.contains("--version")

// Configure logging based on flags
if args.contains("--silent") {
    Logger.isSilent = true
} else if args.contains("--quiet") {
    Logger.setLogLevel(.error)
}

// Require root for all operations except help/version
if !isHelpRequest && getuid() != 0 {
    fputs("Error: brewmeister requires root privileges\n", stderr)
    fputs("Run with: sudo brewmeister [command]\n", stderr)
    fputs("\n", stderr)
    fputs("For help: brewmeister --help (no sudo required)\n", stderr)
    exit(1)
}

// Entry point
BrewmeisterCommand.main()
