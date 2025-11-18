import ArgumentParser
import Foundation

/// Uninstall command - removes brewmeister and optionally Homebrew
struct UninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "removemeister",
        abstract: "Remove brewmeister (and optionally Homebrew)"
    )

    @Flag(name: .long, help: "Keep Homebrew installation and packages")
    var keepHomebrew: Bool = false

    @Flag(name: .long, help: "Show what would be removed without actually removing")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Proceed with uninstall without confirmation")
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
        }

        Logger.info("Brewmeister removemeister")

        // Check privileges
        _ = try PrivilegeManager.shared.ensureSudoAccess()

        // Load configuration
        guard let config = Configuration.load() else {
            Logger.warning("Brewmeister is not configured")
            return
        }

        // Show what will be removed
        if dryRun {
            Logger.info("Dry run - showing what would be removed:")
        } else {
            Logger.warning("This will remove:")
        }

        Logger.info("  • Brewmeister binary: /usr/local/bin/brewmeister")
        Logger.info("  • Service account: \(config.serviceAccount)")
        Logger.info("  • Configuration: /private/var/db/brewmeister/")
        Logger.info("  • Sudoers file: /private/etc/sudoers.d/\(config.serviceAccount)")
        Logger.info("  • PATH file: /etc/paths.d/00-brewmeister")

        if !keepHomebrew {
            Logger.info("  • Homebrew installation: \(config.brewPrefix)")
            Logger.info("  • All installed packages")
        } else {
            Logger.info("")
            Logger.info("Note: Homebrew at \(config.brewPrefix) will be preserved")
            Logger.info("      (--keep-homebrew flag set)")
        }

        Logger.info("")

        // Exit if dry run
        if dryRun {
            Logger.info("Run without --dry-run to perform removal")
            return
        }

        // Exit if not forced (require explicit confirmation)
        if !force {
            Logger.warning("Run with --force to proceed with removal")
            return
        }

        // 1. Remove brewmeister binary
        Logger.info("Removing brewmeister binary...")
        do {
            try FileSystemManager.remove("/usr/local/bin/brewmeister")
            Logger.success("Removed /usr/local/bin/brewmeister")
        } catch {
            Logger.warning("Could not remove brewmeister binary: \(error.localizedDescription)")
        }

        // 2. Remove PATH configuration
        Logger.info("Removing PATH configuration...")
        do {
            try FileSystemManager.remove("/etc/paths.d/00-brewmeister")
            Logger.success("Removed PATH configuration")
        } catch {
            Logger.warning("Could not remove PATH file: \(error.localizedDescription)")
        }

        // 3. Remove sudoers file
        Logger.info("Removing sudoers configuration...")
        do {
            try FileSystemManager.remove("/private/etc/sudoers.d/\(config.serviceAccount)")
            Logger.success("Removed sudoers configuration")
        } catch {
            Logger.warning("Could not remove sudoers file: \(error.localizedDescription)")
        }

        // 4. Remove Homebrew installation unless --keep-homebrew
        if !keepHomebrew {
            Logger.info("Removing Homebrew installation at \(config.brewPrefix)...")
            do {
                try FileSystemManager.remove(config.brewPrefix)
                Logger.success("Removed Homebrew installation")
            } catch {
                Logger.error("Failed to remove Homebrew: \(error.localizedDescription)")
            }
        }

        // 5. Remove service account home directory
        Logger.info("Removing service account home directory...")
        do {
            if let account = try? ServiceAccountManager.getAccount(config.serviceAccount) {
                if FileSystemManager.exists(account.homeDirectory) && account.homeDirectory != "/var/empty" {
                    try FileSystemManager.remove(account.homeDirectory)
                    Logger.success("Removed home directory: \(account.homeDirectory)")
                }
            }
        } catch {
            Logger.warning("Could not remove home directory: \(error.localizedDescription)")
        }

        // 6. Delete service account
        Logger.info("Deleting service account: \(config.serviceAccount)...")
        do {
            try ServiceAccountManager.deleteAccount(config.serviceAccount, removeHome: false)
            Logger.success("Deleted service account")
        } catch {
            Logger.error("Failed to delete service account: \(error.localizedDescription)")
        }

        // 7. Remove configuration
        Logger.info("Removing configuration...")
        do {
            try Configuration.remove()
            // Also try to remove the config directory if empty
            try? FileSystemManager.remove("/private/var/db/brewmeister")
            Logger.success("Removed configuration")
        } catch {
            Logger.warning("Could not remove configuration: \(error.localizedDescription)")
        }

        print("\n" + String(repeating: "=", count: 60))
        Logger.success("Brewmeister removemeister complete!")
        print(String(repeating: "=", count: 60))

        if keepHomebrew {
            print("\nNote: Homebrew installation preserved at \(config.brewPrefix)")
            print("To manually remove: sudo rm -rf \(config.brewPrefix)")
        }
    }
}
