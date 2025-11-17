import XCTest
@testable import brewmeister

final class ArchitectureTests: XCTestCase {
    func testCurrentArchitecture() {
        let arch = Architecture.current

        #if arch(arm64)
        XCTAssertEqual(arch, .arm64, "Current architecture should be arm64")
        #else
        XCTAssertEqual(arch, .x86_64, "Current architecture should be x86_64")
        #endif
    }

    func testArchitectureRawValues() {
        XCTAssertEqual(Architecture.arm64.rawValue, "arm64")
        XCTAssertEqual(Architecture.x86_64.rawValue, "x86_64")
    }

    func testArchPrefix() {
        let arm64Prefix = Architecture.arm64.archPrefix
        let x86Prefix = Architecture.x86_64.archPrefix

        // arm64 requires ["arch", "-arm64"] prefix for forced ARM execution
        // x86_64 doesn't need prefix (can run natively or under Rosetta)
        XCTAssertEqual(arm64Prefix, ["arch", "-arm64"], "arm64 requires arch prefix")
        XCTAssertEqual(x86Prefix, [], "x86_64 doesn't require arch prefix")
    }

    func testRequiresArchPrefix() {
        // arm64 requires prefix, x86_64 doesn't
        XCTAssertTrue(Architecture.arm64.requiresArchPrefix)
        XCTAssertFalse(Architecture.x86_64.requiresArchPrefix)
    }

    func testCodable() throws {
        let arch = Architecture.arm64

        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(arch)

        // Test decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Architecture.self, from: data)

        XCTAssertEqual(arch, decoded)
    }

    func testDecodingFromRawValue() throws {
        let json = "\"arm64\"".data(using: .utf8)!
        let decoder = JSONDecoder()
        let arch = try decoder.decode(Architecture.self, from: json)

        XCTAssertEqual(arch, .arm64)
    }
}
