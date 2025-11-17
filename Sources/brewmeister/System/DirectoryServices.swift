import Foundation
import OpenDirectory

/// Wrapper around OpenDirectory framework for user and group management
class DirectoryServices {
    /// Get the local directory node
    /// - Returns: Local ODNode
    static func getLocalNode() throws -> ODNode {
        let session = ODSession.default()
        do {
            return try ODNode(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
        } catch {
            throw BrewmeisterError.directoryServiceError(underlying: error)
        }
    }

    /// Check if a user exists using dscl
    /// - Parameters:
    ///   - username: Username to check
    ///   - node: Optional ODNode (unused, kept for API compatibility)
    /// - Returns: True if user exists
    static func userExists(_ username: String, in node: ODNode? = nil) throws -> Bool {
        let result = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "read", "/Users/\(username)"],
            captureOutput: true
        )
        return result.succeeded
    }

    /// Get a user record
    /// - Parameters:
    ///   - username: Username to retrieve
    ///   - node: Optional ODNode
    /// - Returns: ODRecord for the user
    static func getUser(_ username: String, in node: ODNode? = nil) throws -> ODRecord {
        let localNode = try node ?? getLocalNode()

        do {
            return try localNode.record(
                withRecordType: kODRecordTypeUsers,
                name: username,
                attributes: nil
            )
        } catch {
            throw BrewmeisterError.directoryServiceError(underlying: error)
        }
    }

    /// Check if a group exists using dscl
    /// - Parameters:
    ///   - groupname: Group name to check
    ///   - node: Optional ODNode (unused, kept for API compatibility)
    /// - Returns: True if group exists
    static func groupExists(_ groupname: String, in node: ODNode? = nil) throws -> Bool {
        let result = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "read", "/Groups/\(groupname)"],
            captureOutput: true
        )
        return result.succeeded
    }

    /// Get a group record
    /// - Parameters:
    ///   - groupname: Group name to retrieve
    ///   - node: Optional ODNode
    /// - Returns: ODRecord for the group
    static func getGroup(_ groupname: String, in node: ODNode? = nil) throws -> ODRecord {
        let localNode = try node ?? getLocalNode()

        do {
            return try localNode.record(
                withRecordType: kODRecordTypeGroups,
                name: groupname,
                attributes: nil
            )
        } catch {
            throw BrewmeisterError.directoryServiceError(underlying: error)
        }
    }

    /// Create a new user using dscl (more reliable than OpenDirectory API)
    /// - Parameters:
    ///   - username: Username for new user
    ///   - uid: User ID
    ///   - gid: Primary group ID
    ///   - fullName: Full name
    ///   - homeDirectory: Home directory path
    ///   - shell: User shell
    ///   - isHidden: Whether user is hidden
    ///   - node: Optional ODNode
    static func createUser(
        username: String,
        uid: UInt,
        gid: UInt,
        fullName: String,
        homeDirectory: String,
        shell: String = "/bin/zsh",
        isHidden: Bool = true,
        in node: ODNode? = nil
    ) throws {
        // Use dscl to create user (more reliable than OpenDirectory API)
        let userPath = "/Users/\(username)"

        // Create user record
        let createResult = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath], captureOutput: true)
        guard createResult.succeeded else {
            throw BrewmeisterError.userCreationFailed(reason: "dscl create failed: \(createResult.stderr)")
        }

        // Set attributes
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath, "RealName", fullName], captureOutput: true)
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath, "UniqueID", String(uid)], captureOutput: true)
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath, "PrimaryGroupID", String(gid)], captureOutput: true)
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath, "UserShell", shell], captureOutput: true)
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath, "NFSHomeDirectory", homeDirectory], captureOutput: true)
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath, "Password", "*"], captureOutput: true)

        if isHidden {
            _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", userPath, "IsHidden", "1"], captureOutput: true)
        }

        Logger.debug("Created user: \(username) (UID: \(uid))")
    }

    /// Create a new group using dscl (more reliable than OpenDirectory API)
    /// - Parameters:
    ///   - groupname: Group name
    ///   - gid: Group ID
    ///   - fullName: Full name for group
    ///   - isHidden: Whether group is hidden
    ///   - node: Optional ODNode
    static func createGroup(
        groupname: String,
        gid: UInt,
        fullName: String? = nil,
        isHidden: Bool = true,
        in node: ODNode? = nil
    ) throws {
        // Use dscl to create group (more reliable than OpenDirectory API)
        let groupPath = "/Groups/\(groupname)"

        // Create group record
        let createResult = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", groupPath], captureOutput: true)
        guard createResult.succeeded else {
            throw BrewmeisterError.userCreationFailed(reason: "dscl create group failed: \(createResult.stderr)")
        }

        // Set attributes
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", groupPath, "PrimaryGroupID", String(gid)], captureOutput: true)
        _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", groupPath, "Password", "*"], captureOutput: true)

        if let fullName = fullName {
            _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", groupPath, "RealName", fullName], captureOutput: true)
        }

        if isHidden {
            _ = try ProcessExecutor.execute(["/usr/bin/dscl", ".", "create", groupPath, "IsHidden", "1"], captureOutput: true)
        }

        Logger.debug("Created group: \(groupname) (GID: \(gid))")
    }

    /// Add a user to a group using dscl
    /// - Parameters:
    ///   - username: Username to add
    ///   - groupname: Group name
    ///   - node: Optional ODNode
    static func addUserToGroup(
        username: String,
        groupname: String,
        in node: ODNode? = nil
    ) throws {
        // Use dscl to add user to group
        let groupPath = "/Groups/\(groupname)"

        _ = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "append", groupPath, "GroupMembership", username],
            captureOutput: true
        )

        Logger.debug("Added user \(username) to group \(groupname)")
    }

    /// Delete a user using dscl
    /// - Parameters:
    ///   - username: Username to delete
    ///   - node: Optional ODNode
    static func deleteUser(_ username: String, in node: ODNode? = nil) throws {
        let userPath = "/Users/\(username)"

        _ = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "delete", userPath],
            captureOutput: true
        )

        Logger.debug("Deleted user: \(username)")
    }

    /// Delete a group using dscl
    /// - Parameters:
    ///   - groupname: Group name to delete
    ///   - node: Optional ODNode
    static func deleteGroup(_ groupname: String, in node: ODNode? = nil) throws {
        let groupPath = "/Groups/\(groupname)"

        _ = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "delete", groupPath],
            captureOutput: true
        )

        Logger.debug("Deleted group: \(groupname)")
    }

    /// Find the next available UID in a range using dscl
    /// - Parameters:
    ///   - startingUID: UID to start searching from
    ///   - endingUID: Maximum UID to check (default 999 for system range)
    ///   - node: Optional ODNode (unused, kept for API compatibility)
    /// - Returns: Next available UID
    static func findNextAvailableUID(
        from startingUID: UInt = 900,
        to endingUID: UInt = 999,
        in node: ODNode? = nil
    ) throws -> UInt {
        // Get list of all UIDs using dscl
        let result = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "list", "/Users", "UniqueID"],
            captureOutput: true
        )

        guard result.succeeded else {
            throw BrewmeisterError.directoryServiceError(
                underlying: NSError(domain: "dscl", code: result.exitCode, userInfo: nil)
            )
        }

        // Parse UIDs from output
        var usedUIDs = Set<UInt>()
        for line in result.stdout.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 2, let uid = UInt(parts.last!) {
                usedUIDs.insert(uid)
            }
        }

        // Find first available UID
        for uid in startingUID...endingUID {
            if !usedUIDs.contains(uid) {
                return uid
            }
        }

        throw BrewmeisterError.noAvailableUID
    }

    /// Get the UID for a username using dscl
    /// - Parameters:
    ///   - username: Username
    ///   - node: Optional ODNode (unused, kept for API compatibility)
    /// - Returns: UID
    static func getUID(for username: String, in node: ODNode? = nil) throws -> UInt {
        let result = try ProcessExecutor.execute(
            ["/usr/bin/dscl", ".", "read", "/Users/\(username)", "UniqueID"],
            captureOutput: true
        )

        guard result.succeeded else {
            throw BrewmeisterError.userCreationFailed(reason: "Could not read UID for \(username)")
        }

        // Parse output: "UniqueID: 901"
        let lines = result.stdout.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == "UniqueID" {
                if let uid = UInt(parts[1].trimmingCharacters(in: .whitespaces)) {
                    return uid
                }
            }
        }

        throw BrewmeisterError.userCreationFailed(reason: "Could not parse UID from dscl output")
    }
}
