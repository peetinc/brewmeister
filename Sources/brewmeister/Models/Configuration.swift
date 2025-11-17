import Foundation

/// Brewmeister configuration stored on disk
struct Configuration: Codable {
    /// The service account username
    let serviceAccount: String

    /// The Homebrew installation prefix
    let brewPrefix: String

    /// The system architecture
    let architecture: Architecture

    /// The brewmeister version
    let version: String

    /// Path to the configuration file
    private static let configPath = "/private/var/db/brewmeister/config.json"

    /// Initialize a new configuration
    init(serviceAccount: String, brewPrefix: String, architecture: Architecture, version: String = "2.0.0") {
        self.serviceAccount = serviceAccount
        self.brewPrefix = brewPrefix
        self.architecture = architecture
        self.version = version
    }

    /// Save the configuration to disk
    func save() throws {
        let configURL = URL(fileURLWithPath: Configuration.configPath)
        let directory = configURL.deletingLastPathComponent()

        // Create directory if needed
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Encode and write
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: configURL, options: .atomic)
    }

    /// Load the configuration from disk
    static func load() -> Configuration? {
        let configURL = URL(fileURLWithPath: configPath)

        guard let data = try? Data(contentsOf: configURL) else {
            return nil
        }

        return try? JSONDecoder().decode(Configuration.self, from: data)
    }

    /// Check if configuration exists
    static func exists() -> Bool {
        return FileManager.default.fileExists(atPath: configPath)
    }

    /// Remove the configuration file
    static func remove() throws {
        try FileManager.default.removeItem(atPath: configPath)
    }
}
