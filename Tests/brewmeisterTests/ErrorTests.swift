import XCTest
@testable import brewmeister

final class ErrorTests: XCTestCase {
    // MARK: - Setup Errors

    func testInsufficientPrivilegesError() {
        let error = BrewmeisterError.insufficientPrivileges

        XCTAssertEqual(
            error.errorDescription,
            "Insufficient privileges to perform this operation"
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Run this command with sudo: sudo brewmeister setup"
        )
    }

    func testUserCreationFailedError() {
        let error = BrewmeisterError.userCreationFailed(reason: "UID already exists")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to create service account: UID already exists"
        )
    }

    func testHomebrewInstallationFailedError() {
        let error = BrewmeisterError.homebrewInstallationFailed(reason: "Network timeout")

        XCTAssertEqual(
            error.errorDescription,
            "Failed to install Homebrew: Network timeout"
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Check network connectivity and try again"
        )
    }

    func testCommandLineToolsMissingError() {
        let error = BrewmeisterError.commandLineToolsMissing

        XCTAssertEqual(
            error.errorDescription,
            "Xcode Command Line Tools are not installed"
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Install Xcode Command Line Tools: xcode-select --install"
        )
    }

    func testNoAvailableUIDError() {
        let error = BrewmeisterError.noAvailableUID

        XCTAssertEqual(
            error.errorDescription,
            "No available UID found in the system range (900-999)"
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Free up UIDs in the 900-999 range or modify the starting UID"
        )
    }

    func testInvalidSudoersFileError() {
        let error = BrewmeisterError.invalidSudoersFile

        XCTAssertEqual(
            error.errorDescription,
            "Generated sudoers file failed validation"
        )
    }

    // MARK: - Runtime Errors

    func testNotConfiguredError() {
        let error = BrewmeisterError.notConfigured(message: "Configuration file not found")

        XCTAssertEqual(
            error.errorDescription,
            "Brewmeister is not configured: Configuration file not found"
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Run 'sudo brewmeister setup' first to configure the service account"
        )
    }

    func testServiceAccountNotFoundError() {
        let error = BrewmeisterError.serviceAccountNotFound("_brewmeister")

        XCTAssertEqual(
            error.errorDescription,
            "Service account '_brewmeister' not found in directory services"
        )
        XCTAssertEqual(
            error.recoverySuggestion,
            "Run 'sudo brewmeister setup' to create the service account"
        )
    }

    func testBrewExecutionFailedError() {
        let error = BrewmeisterError.brewExecutionFailed(
            exitCode: 1,
            stderr: "Error: Package not found"
        )

        XCTAssertEqual(
            error.errorDescription,
            "Brew command failed with exit code 1"
        )
        XCTAssertTrue(
            error.recoverySuggestion?.contains("Error: Package not found") ?? false
        )
    }

    func testBrewExecutionFailedErrorWithoutStderr() {
        let error = BrewmeisterError.brewExecutionFailed(exitCode: 1, stderr: "")

        XCTAssertEqual(
            error.errorDescription,
            "Brew command failed with exit code 1"
        )
        XCTAssertNil(error.recoverySuggestion)
    }

    // MARK: - System Errors

    func testDirectoryServiceError() {
        struct DummyError: Error {}
        let error = BrewmeisterError.directoryServiceError(underlying: DummyError())

        XCTAssertTrue(
            error.errorDescription?.contains("Directory services error") ?? false
        )
    }

    func testFileSystemError() {
        struct DummyError: Error {}
        let error = BrewmeisterError.fileSystemError(underlying: DummyError())

        XCTAssertTrue(
            error.errorDescription?.contains("Filesystem error") ?? false
        )
    }

    func testProcessExecutionFailedError() {
        let error = BrewmeisterError.processExecutionFailed(
            command: "/usr/bin/brew",
            exitCode: 127
        )

        XCTAssertEqual(
            error.errorDescription,
            "Process '/usr/bin/brew' failed with exit code 127"
        )
    }

    // MARK: - Error as LocalizedError

    func testErrorLocalizedDescription() {
        let error: LocalizedError = BrewmeisterError.insufficientPrivileges

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }
}
