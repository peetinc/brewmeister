import Foundation
import OpenDirectory

/// Manages the brewmeister service account
class ServiceAccountManager {
    /// Create a service account for running Homebrew
    /// - Parameters:
    ///   - username: Username (e.g., "_brewmeister")
    ///   - fullName: Full name for the account
    ///   - homeDirectory: Home directory path
    ///   - startingUID: UID to start searching from (default 900)
    /// - Returns: Created ServiceAccount
    static func createAccount(
        username: String,
        fullName: String,
        homeDirectory: String,
        startingUID: UInt = 900
    ) throws -> ServiceAccount {
        Logger.info("Creating service account: \(username)")

        // Check if user already exists
        if try DirectoryServices.userExists(username) {
            Logger.warning("User \(username) already exists, retrieving existing account")
            let uid = try DirectoryServices.getUID(for: username)
            return ServiceAccount(
                username: username,
                uid: uid,
                gid: uid, // Assume GID matches UID
                homeDirectory: homeDirectory
            )
        }

        // Find available UID
        let uid = try DirectoryServices.findNextAvailableUID(from: startingUID)
        let gid = uid // Use same value for GID

        Logger.debug("Found available UID/GID: \(uid)")

        // Create group first
        do {
            if try !DirectoryServices.groupExists(username) {
                try DirectoryServices.createGroup(
                    groupname: username,
                    gid: gid,
                    fullName: fullName,
                    isHidden: true
                )
            }
        } catch {
            Logger.warning("Failed to create group, continuing: \(error.localizedDescription)")
        }

        // Create user
        try DirectoryServices.createUser(
            username: username,
            uid: uid,
            gid: 80, // admin group as primary
            fullName: fullName,
            homeDirectory: homeDirectory,
            shell: "/bin/zsh",
            isHidden: true
        )

        // Add to groups
        do {
            // Add to self-named group
            try DirectoryServices.addUserToGroup(username: username, groupname: username)
        } catch {
            Logger.debug("Could not add to self-named group: \(error.localizedDescription)")
        }

        do {
            // Add to admin group
            try DirectoryServices.addUserToGroup(username: username, groupname: "admin")
        } catch {
            Logger.warning("Could not add to admin group: \(error.localizedDescription)")
        }

        // Create home directory
        Logger.debug("Creating home directory: \(homeDirectory)")
        try FileSystemManager.createDirectory(
            at: homeDirectory,
            owner: username,
            group: username,
            permissions: 0o700,
            withIntermediateDirectories: true
        )

        Logger.success("Created service account: \(username) (UID: \(uid))")

        return ServiceAccount(
            username: username,
            uid: uid,
            gid: gid,
            homeDirectory: homeDirectory
        )
    }

    /// Check if a service account exists
    /// - Parameter username: Username to check
    /// - Returns: True if account exists
    static func accountExists(_ username: String) throws -> Bool {
        return try DirectoryServices.userExists(username)
    }

    /// Get information about an existing service account
    /// - Parameter username: Username
    /// - Returns: ServiceAccount with current information
    static func getAccount(_ username: String) throws -> ServiceAccount {
        let uid = try DirectoryServices.getUID(for: username)
        let user = try DirectoryServices.getUser(username)

        // Get home directory
        let homeValues = try user.values(forAttribute: kODAttributeTypeNFSHomeDirectory)
        let homeDirectory = homeValues.first as? String ?? "/var/empty"

        return ServiceAccount(
            username: username,
            uid: uid,
            gid: uid, // Assume GID matches UID
            homeDirectory: homeDirectory
        )
    }

    /// Delete a service account
    /// - Parameters:
    ///   - username: Username to delete
    ///   - removeHome: Whether to remove home directory
    static func deleteAccount(_ username: String, removeHome: Bool = false) throws {
        Logger.info("Deleting service account: \(username)")

        if removeHome {
            if let account = try? getAccount(username) {
                if FileSystemManager.exists(account.homeDirectory) {
                    try FileSystemManager.remove(account.homeDirectory)
                }
            }
        }

        // Delete user
        try DirectoryServices.deleteUser(username)

        // Delete group if exists
        if try DirectoryServices.groupExists(username) {
            try DirectoryServices.deleteGroup(username)
        }

        Logger.success("Deleted service account: \(username)")
    }
}
