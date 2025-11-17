import Foundation

/// Manages filesystem operations with proper permissions
class FileSystemManager {
    /// Create a directory with specific owner, group, and permissions
    /// - Parameters:
    ///   - path: Directory path to create
    ///   - owner: Owner username (optional, requires privileges)
    ///   - group: Group name (optional, requires privileges)
    ///   - permissions: POSIX permissions (e.g., 0o755)
    ///   - intermediates: Create intermediate directories if needed
    static func createDirectory(
        at path: String,
        owner: String? = nil,
        group: String? = nil,
        permissions: mode_t = 0o755,
        withIntermediateDirectories intermediates: Bool = true
    ) throws {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        // Create directory
        if !fileManager.fileExists(atPath: path) {
            do {
                let attributes: [FileAttributeKey: Any] = [
                    .posixPermissions: permissions
                ]

                try fileManager.createDirectory(
                    at: url,
                    withIntermediateDirectories: intermediates,
                    attributes: attributes
                )

                Logger.debug("Created directory: \(path)")
            } catch {
                throw BrewmeisterError.fileSystemError(underlying: error)
            }
        }

        // Set ownership if specified (requires running as root or with sudo)
        if let owner = owner {
            try changeOwnership(
                path: path,
                owner: owner,
                group: group,
                recursive: false
            )
        }

        // Set permissions
        try setPermissions(path: path, permissions: permissions)
    }

    /// Change ownership of a file or directory
    /// - Parameters:
    ///   - path: Path to change
    ///   - owner: New owner username
    ///   - group: New group name (optional)
    ///   - recursive: Apply recursively to contents
    static func changeOwnership(
        path: String,
        owner: String,
        group: String? = nil,
        recursive: Bool = false
    ) throws {
        var chownCommand = ["/usr/sbin/chown"]

        if recursive {
            chownCommand.append("-R")
        }

        let ownerString = group != nil ? "\(owner):\(group!)" : owner
        chownCommand.append(ownerString)
        chownCommand.append(path)

        Logger.debug("Executing: \(chownCommand.joined(separator: " "))")

        let result = try ProcessExecutor.execute(chownCommand, captureOutput: true)

        guard result.succeeded else {
            Logger.error("chown failed with exit code \(result.exitCode)")
            Logger.error("stdout: \(result.stdout)")
            Logger.error("stderr: \(result.stderr)")
            throw BrewmeisterError.fileSystemError(
                underlying: NSError(
                    domain: "FileSystemManager",
                    code: result.exitCode,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to change ownership of \(path) to \(ownerString): \(result.stderr)"]
                )
            )
        }

        Logger.debug("Changed ownership of \(path) to \(ownerString)")
    }

    /// Set permissions on a file or directory
    /// - Parameters:
    ///   - path: Path to modify
    ///   - permissions: POSIX permissions (e.g., 0o755)
    static func setPermissions(path: String, permissions: mode_t) throws {
        let fileManager = FileManager.default

        do {
            try fileManager.setAttributes(
                [.posixPermissions: permissions],
                ofItemAtPath: path
            )
            Logger.debug("Set permissions on \(path) to \(String(permissions, radix: 8))")
        } catch {
            throw BrewmeisterError.fileSystemError(underlying: error)
        }
    }

    /// Check if a path exists
    /// - Parameter path: Path to check
    /// - Returns: True if exists
    static func exists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    /// Check if a path is a directory
    /// - Parameter path: Path to check
    /// - Returns: True if path exists and is a directory
    static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// Remove a file or directory
    /// - Parameter path: Path to remove
    static func remove(_ path: String) throws {
        do {
            try FileManager.default.removeItem(atPath: path)
            Logger.debug("Removed: \(path)")
        } catch {
            throw BrewmeisterError.fileSystemError(underlying: error)
        }
    }

    /// Write string content to a file
    /// - Parameters:
    ///   - content: String content to write
    ///   - path: File path
    ///   - atomically: Write atomically (safer)
    static func writeString(
        _ content: String,
        to path: String,
        atomically: Bool = true
    ) throws {
        do {
            try content.write(
                toFile: path,
                atomically: atomically,
                encoding: .utf8
            )
            Logger.debug("Wrote file: \(path)")
        } catch {
            throw BrewmeisterError.fileSystemError(underlying: error)
        }
    }

    /// Read string content from a file
    /// - Parameter path: File path
    /// - Returns: File contents as string
    static func readString(from path: String) throws -> String {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw BrewmeisterError.fileSystemError(underlying: error)
        }
    }
}
