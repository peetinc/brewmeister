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

// Entry point
BrewmeisterCommand.main()
