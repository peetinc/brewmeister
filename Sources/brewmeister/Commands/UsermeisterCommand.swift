import ArgumentParser
import Foundation

/// Usermeister command - enables regular users to use brewmeister's Homebrew
struct UsermeisterCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "usermeister",
        abstract: "Enable a user to access brewmeister's Homebrew installation"
    )

    @Argument(help: "Username to enable (defaults to current sudo user)")
    var username: String?

    @Flag(name: [.short, .long], help: "Enable verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Force reconfiguration even if already configured")
    var force: Bool = false

    @Flag(name: .long, help: "Only show errors")
    var quiet: Bool = false

    @Flag(name: .long, help: "No output at all")
    var silent: Bool = false

    func run() throws {
        // Configure logging based on flags
        if silent {
            Logger.isSilent = true
        } else if quiet {
            Logger.setLogLevel(.error)
        } else if verbose {
            Logger.setLogLevel(.debug)
        }

        // Determine target username
        let targetUsername: String
        if let providedUsername = username {
            targetUsername = providedUsername
        } else if let sudoUser = ProcessInfo.processInfo.environment["SUDO_USER"] {
            targetUsername = sudoUser
        } else {
            throw BrewmeisterError.notConfigured(message: "Could not determine username. Run with sudo or provide username explicitly.")
        }

        Logger.info("Configuring user: \(targetUsername)")

        // 1. Validate brewmeister is installed
        guard let config = Configuration.load() else {
            throw BrewmeisterError.notConfigured(message: "brewmeister is not installed. Run 'sudo brewmeister setupmeister' first.")
        }

        Logger.debug("Found brewmeister configuration: \(config.brewPrefix)")

        // 2. Validate target user exists
        guard try DirectoryServices.userExists(targetUsername) else {
            throw BrewmeisterError.notConfigured(message: "User '\(targetUsername)' does not exist")
        }

        // 3. Get user's home directory
        let homeDir = try getUserHomeDirectory(username: targetUsername)
        let zshrcPath = "\(homeDir)/.zshrc"

        Logger.debug("User home directory: \(homeDir)")
        Logger.debug("zshrc path: \(zshrcPath)")

        // 4. Check if already configured (unless force)
        if !force {
            if let existingContent = try? String(contentsOfFile: zshrcPath, encoding: .utf8) {
                if existingContent.contains("# >>> brewmeister initialize >>>") {
                    Logger.warning("User '\(targetUsername)' is already configured for brewmeister")
                    Logger.info("Use --force to reconfigure")
                    return
                }
            }
        }

        // 5. Modify .zshrc
        try configureZshrc(path: zshrcPath, brewPrefix: config.brewPrefix)

        Logger.info("✓ User '\(targetUsername)' configured successfully")
        Logger.info("")
        Logger.info("The user can now run 'brew' commands:")
        Logger.info("  - Commands will execute as service account '\(config.serviceAccount)'")
        Logger.info("  - Sudo password will be required for each brew command")
        Logger.info("")
        Logger.info("To apply changes, the user should run:")
        Logger.info("  source ~/.zshrc")
        Logger.info("")
        Logger.info("OPTIONAL - Passwordless sudo for brewmeister:")
        Logger.info("  ⚠️  AT YOUR OWN RISK - Understand the security implications!")
        Logger.info("  This allows '\(targetUsername)' to run brewmeister without password prompts.")
        Logger.info("")
        Logger.info("  Run this command to enable:")
        let sudoersOneLiner = "echo \"\(targetUsername) ALL = (ALL) NOPASSWD: /usr/local/bin/brewmeister\" | sudo tee /tmp/sudoers-brewmeister >/dev/null && sudo visudo -c -f /tmp/sudoers-brewmeister && sudo install -o root -g wheel -m 0440 /tmp/sudoers-brewmeister /etc/sudoers.d/\(targetUsername) && sudo rm /tmp/sudoers-brewmeister"
        Logger.info("  \(sudoersOneLiner)")
    }

    /// Get home directory for a user
    private func getUserHomeDirectory(username: String) throws -> String {
        let result = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "read", "/Users/\(username)", "NFSHomeDirectory"],
            captureOutput: true
        )

        guard result.succeeded else {
            throw BrewmeisterError.notConfigured(message: "Could not read home directory for user '\(username)'")
        }

        // Parse output: "NFSHomeDirectory: /Users/username"
        let lines = result.stdout.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == "NFSHomeDirectory" {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        throw BrewmeisterError.notConfigured(message: "Could not parse home directory from dscl output")
    }

    /// Configure .zshrc for brewmeister
    private func configureZshrc(path: String, brewPrefix: String) throws {
        Logger.info("Configuring zsh environment...")

        // Read existing .zshrc or create empty string
        var existingContent = ""
        if FileManager.default.fileExists(atPath: path) {
            // Create backup
            let backupPath = "\(path).brewmeister-backup"
            try? FileManager.default.copyItem(atPath: path, toPath: backupPath)
            Logger.debug("Created backup: \(backupPath)")

            existingContent = try String(contentsOfFile: path, encoding: .utf8)

            // If force mode, remove existing brewmeister section
            if force {
                existingContent = removeBrewmeisterSection(from: existingContent)
            }
        } else {
            Logger.debug("Creating new .zshrc file")
        }

        // Prepare brewmeister section
        let brewmeisterSection = """
        # >>> brewmeister initialize >>>
        # Enable brewmeister's Homebrew installation
        # This must come after any other Homebrew shellenv to override PATH
        eval "$(\(brewPrefix)/bin/brew shellenv)"
        alias brew='sudo brewmeister brew'
        # <<< brewmeister initialize <<<
        """

        // Append brewmeister section (ensures it comes AFTER any existing homebrew shellenv)
        var newContent = existingContent
        if !newContent.isEmpty && !newContent.hasSuffix("\n") {
            newContent += "\n"
        }
        newContent += "\n\(brewmeisterSection)\n"

        // Write updated .zshrc
        try newContent.write(toFile: path, atomically: true, encoding: .utf8)

        // Ensure proper ownership
        let owner = path.split(separator: "/")[2] // Extract username from /Users/username
        _ = try? ProcessExecutor.execute(
            ["/usr/sbin/chown", String(owner), path],
            captureOutput: true
        )

        Logger.debug("✓ Updated \(path)")
    }

    /// Remove existing brewmeister section from content
    private func removeBrewmeisterSection(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []
        var inBrewmeisterSection = false

        for line in lines {
            if line.contains("# >>> brewmeister initialize >>>") {
                inBrewmeisterSection = true
                continue
            }
            if line.contains("# <<< brewmeister initialize <<<") {
                inBrewmeisterSection = false
                continue
            }
            if !inBrewmeisterSection {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}
