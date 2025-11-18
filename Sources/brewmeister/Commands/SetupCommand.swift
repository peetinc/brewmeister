import ArgumentParser
import Foundation

/// Setup command - creates service account and installs Homebrew
struct SetupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setupmeister",
        abstract: "Install brewmeister service account and Homebrew"
    )

    @Option(name: .long, help: "Service account username")
    var username: String = "_brewmeister"

    @Option(name: .long, help: "Homebrew installation directory")
    var prefix: String = "/opt/brewmeister"

    @Flag(name: .long, help: "Skip Xcode Command Line Tools check")
    var skipCLTools: Bool = false

    @Flag(name: .long, help: "Skip brew doctor after installation")
    var skipDoctor: Bool = false

    @Flag(name: [.short, .long], help: "Enable verbose output")
    var verbose: Bool = false

    @Flag(name: .long, help: "Force reinstall even if already configured")
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

        Logger.info("Starting brewmeister setupmeister")
        Logger.info("Service account: \(username)")
        Logger.info("Homebrew prefix: \(prefix)")

        // 1. Check privileges
        Logger.info("Checking sudo access...")
        _ = try PrivilegeManager.shared.ensureSudoAccess()

        // 2. Check for existing configuration
        if Configuration.exists() && !force {
            Logger.warning("Brewmeister is already configured")
            if let existing = Configuration.load() {
                Logger.info("Existing configuration:")
                Logger.info("  Service account: \(existing.serviceAccount)")
                Logger.info("  Brew prefix: \(existing.brewPrefix)")
                Logger.info("  Architecture: \(existing.architecture.rawValue)")
                Logger.info("")
                Logger.info("Run with --force to reinstall")
                return
            }
        }

        if force && Configuration.exists() {
            Logger.info("Force reinstall requested, continuing...")
        }

        // 3. Check Command Line Tools (unless skipped)
        if !skipCLTools {
            Logger.info("Checking Xcode Command Line Tools...")
            do {
                try CommandLineToolsInstaller.ensureInstalled()
            } catch BrewmeisterError.commandLineToolsMissing {
                Logger.error("Xcode Command Line Tools are required")
                Logger.info("Install with: xcode-select --install")
                Logger.info("Or run setupmeister with --skip-cl-tools to bypass this check")
                throw BrewmeisterError.commandLineToolsMissing
            }
        }

        // 4. Create service account
        Logger.info("Creating service account: \(username)")
        let homeDirectory = "/var/brewmeister"  // Writable home for caches/locks

        let account = try ServiceAccountManager.createAccount(
            username: username,
            fullName: "Brewmeister Service Account",
            homeDirectory: homeDirectory,
            startingUID: 900
        )

        Logger.success("Service account created: \(account.username) (UID: \(account.uid))")

        // 4a. Create .zshrc for brewmeister user
        Logger.debug("Creating .zshrc for \(account.username)")
        let zshrcPath = "\(homeDirectory)/.zshrc"
        let zshrcContent = """
        # Brewmeister Homebrew environment
        eval "$(\(prefix)/bin/brew shellenv)"
        """
        try FileSystemManager.writeString(zshrcContent, to: zshrcPath, atomically: true)
        try FileSystemManager.changeOwnership(path: zshrcPath, owner: account.username, group: "admin")
        try FileSystemManager.setPermissions(path: zshrcPath, permissions: 0o644)

        // 5. Configure passwordless sudo
        Logger.info("Configuring passwordless sudo...")
        try PrivilegeManager.shared.configurePasswordlessSudo(
            for: account,
            brewPrefix: prefix
        )

        // 6. Install Homebrew
        Logger.info("Installing Homebrew to \(prefix)")
        try HomebrewInstaller.install(
            toPath: prefix,
            ownedBy: account
        )

        // 7. Run brew doctor (unless skipped)
        if !skipDoctor {
            do {
                try HomebrewInstaller.doctor(at: prefix, asUser: account.username)
            } catch {
                Logger.warning("Brew doctor encountered issues (non-fatal)")
            }
        }

        // 8. Save configuration
        Logger.info("Saving configuration...")
        let config = Configuration(
            serviceAccount: account.username,
            brewPrefix: prefix,
            architecture: SystemInfo.architecture,
            version: "2.0.0"
        )
        try config.save()

        // 9. Add to PATH
        Logger.info("Setting up PATH...")
        let pathsDir = "/etc/paths.d"
        // Use "00-brewmeister" to ensure it's processed first (alphabetical order)
        let pathsFile = "\(pathsDir)/00-brewmeister"

        if !FileSystemManager.exists(pathsDir) {
            try FileSystemManager.createDirectory(at: pathsDir)
        }

        let pathContent = """
        \(prefix)/bin
        \(prefix)/sbin
        """

        try FileSystemManager.writeString(pathContent, to: pathsFile, atomically: true)
        try FileSystemManager.setPermissions(path: pathsFile, permissions: 0o644)

        Logger.success("PATH configured (\(pathsFile))")

        // 10. Install brewmeister binary to /usr/local/bin
        Logger.info("Installing brewmeister to /usr/local/bin...")
        let installPath = "/usr/local/bin/brewmeister"

        // Get current executable path
        let executablePath = CommandLine.arguments[0]

        // Ensure /usr/local/bin exists
        if !FileSystemManager.exists("/usr/local/bin") {
            try FileSystemManager.createDirectory(at: "/usr/local/bin", withIntermediateDirectories: true)
        }

        // Copy brewmeister binary
        do {
            let copyResult = try ProcessExecutor.execute([
                "/bin/cp", executablePath, installPath
            ], captureOutput: true)

            if copyResult.succeeded {
                // Set executable permissions
                try FileSystemManager.setPermissions(path: installPath, permissions: 0o755)
                Logger.success("Brewmeister installed to \(installPath)")
            } else {
                Logger.warning("Could not copy brewmeister to \(installPath)")
                Logger.warning("You can manually copy it later: sudo cp \(executablePath) \(installPath)")
            }
        } catch {
            Logger.warning("Could not install brewmeister: \(error.localizedDescription)")
            Logger.warning("You can manually copy it later: sudo cp \(executablePath) \(installPath)")
        }

        // 11. Install man page
        Logger.info("Installing man page...")
        do {
            // Determine source path for man page (relative to executable)
            let executableURL = URL(fileURLWithPath: executablePath)
            let projectRoot = executableURL.deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let manPageSource = projectRoot.appendingPathComponent("man/brewmeister.1").path
            let manPageDest = "/usr/local/share/man/man1/brewmeister.1"

            if FileSystemManager.exists(manPageSource) {
                // Create man directory if needed
                let manDir = "/usr/local/share/man/man1"
                if !FileSystemManager.exists(manDir) {
                    try FileSystemManager.createDirectory(at: manDir, withIntermediateDirectories: true)
                }

                // Copy man page
                let copyResult = try ProcessExecutor.execute([
                    "/bin/cp", manPageSource, manPageDest
                ], captureOutput: true)

                if copyResult.succeeded {
                    try FileSystemManager.setPermissions(path: manPageDest, permissions: 0o644)
                    Logger.success("Man page installed to \(manPageDest)")
                } else {
                    Logger.warning("Failed to install man page")
                }
            } else {
                Logger.warning("Man page not found at \(manPageSource)")
                Logger.info("Man page will not be available via 'man brewmeister'")
            }
        } catch {
            Logger.warning("Could not install man page: \(error.localizedDescription)")
        }

        // 12. Display version info
        if let version = HomebrewInstaller.version(at: prefix, asUser: account.username) {
            Logger.info("Installed: \(version)")
        }

        // Done!
        print("\n" + String(repeating: "=", count: 60))
        Logger.success("Brewmeister setupmeister complete!")
        print(String(repeating: "=", count: 60))

        print("\nNext steps:")
        print("  • Install packages: brewmeister install <package>")
        print("  • Upgrade packages: brewmeister upgrade")
        print("  • List packages:    brewmeister list")
        print("  • Check health:     brewmeister healthmeister")
        print("\nInstalled packages are available in:")
        print("  \(prefix)/bin/")
        print("\nbrewmeister is now installed at:")
        print("  \(installPath)")
        print("\nNote: You may need to open a new terminal for PATH changes to take effect")
    }
}
