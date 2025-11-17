import ArgumentParser
import Foundation

struct BrewmeisterCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: Version.bundleName,
        abstract: "Homebrew automation wrapper that enables root-level RMM tools to manage packages via dedicated service account",
        version: Version.version,
        subcommands: [SetupCommand.self, BrewPassthroughCommand.self, BrewCommand.self, HealthCommand.self, UninstallCommand.self, UsermeisterCommand.self],
        defaultSubcommand: BrewCommand.self,
        helpNames: [.short, .long]
    )
}

// Check if this is a help or version request
let args = CommandLine.arguments
let isHelpRequest = args.contains("--help") || args.contains("-h") || args.contains("--version")

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
