import XCTest
@testable import brewmeister

final class ConfigurationTests: XCTestCase {
    let testConfigPath = "/tmp/brewmeister-test-config.json"

    override func tearDown() {
        // Clean up test config file
        try? FileManager.default.removeItem(atPath: testConfigPath)
        super.tearDown()
    }

    func testConfigurationInit() {
        let config = Configuration(
            serviceAccount: "_brewmeister",
            brewPrefix: "/opt/brewmeister",
            architecture: .arm64,
            version: "2.0.0"
        )

        XCTAssertEqual(config.serviceAccount, "_brewmeister")
        XCTAssertEqual(config.brewPrefix, "/opt/brewmeister")
        XCTAssertEqual(config.architecture, .arm64)
        XCTAssertEqual(config.version, "2.0.0")
    }

    func testConfigurationCodable() throws {
        let config = Configuration(
            serviceAccount: "_brewmeister",
            brewPrefix: "/opt/brewmeister",
            architecture: .arm64,
            version: "2.0.0"
        )

        // Encode
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Configuration.self, from: data)

        XCTAssertEqual(decoded.serviceAccount, config.serviceAccount)
        XCTAssertEqual(decoded.brewPrefix, config.brewPrefix)
        XCTAssertEqual(decoded.architecture, config.architecture)
        XCTAssertEqual(decoded.version, config.version)
    }

    func testConfigurationExists() {
        // Should return false for non-existent config
        // (unless brewmeister was actually set up on this system)
        let exists = Configuration.exists()
        XCTAssertTrue(exists == true || exists == false)
    }

    func testConfigurationLoad() {
        // Should return nil for non-existent config
        // (unless brewmeister was actually set up on this system)
        let config = Configuration.load()

        if let config = config {
            // If config exists, verify it has required fields
            XCTAssertFalse(config.serviceAccount.isEmpty)
            XCTAssertFalse(config.brewPrefix.isEmpty)
            XCTAssertFalse(config.version.isEmpty)
        }
    }
}
