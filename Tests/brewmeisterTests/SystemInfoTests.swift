import XCTest
@testable import brewmeister

final class SystemInfoTests: XCTestCase {
    func testArchitecture() {
        let arch = SystemInfo.architecture

        #if arch(arm64)
        XCTAssertEqual(arch, .arm64)
        #else
        XCTAssertEqual(arch, .x86_64)
        #endif
    }

    func testIsRoot() {
        let isRoot = SystemInfo.isRoot

        // In tests, we're typically not running as root
        // But we can verify it returns a boolean
        XCTAssertTrue(isRoot == true || isRoot == false)

        // Verify it matches getuid() check
        let expectedIsRoot = (getuid() == 0)
        XCTAssertEqual(isRoot, expectedIsRoot)
    }

    func testCurrentUsername() {
        let username = SystemInfo.currentUsername

        // Should return a non-empty string
        XCTAssertFalse(username.isEmpty)

        // Should match the environment user
        if let envUser = ProcessInfo.processInfo.environment["USER"] {
            XCTAssertEqual(username, envUser)
        }
    }

    func testCurrentUserHome() {
        let home = SystemInfo.currentUserHome

        // Should return a path
        XCTAssertTrue(home.hasPrefix("/"))

        // Should match environment HOME or NSHomeDirectory()
        if let envHome = ProcessInfo.processInfo.environment["HOME"] {
            XCTAssertEqual(home, envHome)
        }
    }

    func testOSVersion() {
        let version = SystemInfo.osVersion
        XCTAssertFalse(version.isEmpty)
    }

    func testMacOSVersion() {
        let version = SystemInfo.macOSVersion
        XCTAssertGreaterThan(version.majorVersion, 0)
    }

    func testIsAppleSilicon() {
        let isAppleSilicon = SystemInfo.isAppleSilicon

        #if arch(arm64)
        XCTAssertTrue(isAppleSilicon)
        #else
        XCTAssertFalse(isAppleSilicon)
        #endif
    }

    func testMachineHardwareName() {
        let name = SystemInfo.machineHardwareName
        XCTAssertFalse(name.isEmpty)
    }
}
