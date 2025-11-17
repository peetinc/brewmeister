import Foundation

/// Errors that can occur during brewmeister operations
enum BrewmeisterError: LocalizedError {
    // MARK: - Setup Errors

    /// User lacks necessary privileges for the operation
    case insufficientPrivileges

    /// Failed to create service account
    case userCreationFailed(reason: String)

    /// Failed to install Homebrew
    case homebrewInstallationFailed(reason: String)

    /// Xcode Command Line Tools are missing
    case commandLineToolsMissing

    /// No available UID in the specified range
    case noAvailableUID

    /// Sudoers file validation failed
    case invalidSudoersFile

    // MARK: - Runtime Errors

    /// Brewmeister is not configured (setup not run)
    case notConfigured(message: String)

    /// Service account not found in directory services
    case serviceAccountNotFound(String)

    /// Brew command execution failed
    case brewExecutionFailed(exitCode: Int, stderr: String)

    // MARK: - System Errors

    /// Directory services operation failed
    case directoryServiceError(underlying: Error)

    /// Filesystem operation failed
    case fileSystemError(underlying: Error)

    /// Process execution failed
    case processExecutionFailed(command: String, exitCode: Int)

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        case .insufficientPrivileges:
            return "Insufficient privileges to perform this operation"

        case .userCreationFailed(let reason):
            return "Failed to create service account: \(reason)"

        case .homebrewInstallationFailed(let reason):
            return "Failed to install Homebrew: \(reason)"

        case .commandLineToolsMissing:
            return "Xcode Command Line Tools are not installed"

        case .noAvailableUID:
            return "No available UID found in the system range (900-999)"

        case .invalidSudoersFile:
            return "Generated sudoers file failed validation"

        case .notConfigured(let message):
            return "Brewmeister is not configured: \(message)"

        case .serviceAccountNotFound(let username):
            return "Service account '\(username)' not found in directory services"

        case .brewExecutionFailed(let exitCode, _):
            return "Brew command failed with exit code \(exitCode)"

        case .directoryServiceError(let error):
            return "Directory services error: \(error.localizedDescription)"

        case .fileSystemError(let error):
            return "Filesystem error: \(error.localizedDescription)"

        case .processExecutionFailed(let command, let exitCode):
            return "Process '\(command)' failed with exit code \(exitCode)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .insufficientPrivileges:
            return "Run this command with sudo: sudo brewmeister setupmeister"

        case .notConfigured:
            return "Run 'sudo brewmeister setupmeister' first to configure the service account"

        case .serviceAccountNotFound:
            return "Run 'sudo brewmeister setupmeister' to create the service account"

        case .commandLineToolsMissing:
            return "Install Xcode Command Line Tools: xcode-select --install"

        case .noAvailableUID:
            return "Free up UIDs in the 900-999 range or modify the starting UID"

        case .homebrewInstallationFailed:
            return "Check network connectivity and try again"

        case .brewExecutionFailed(_, let stderr):
            if !stderr.isEmpty {
                return "Brew error output:\n\(stderr)"
            }
            return nil

        default:
            return nil
        }
    }
}
