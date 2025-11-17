import Foundation

/// Represents a service account used to run Homebrew
struct ServiceAccount {
    /// The short username (e.g., "_brewmeister")
    let username: String

    /// The user ID (UID)
    let uid: UInt

    /// The group ID (GID)
    let gid: UInt

    /// The home directory path
    let homeDirectory: String

    /// Initialize a service account
    init(username: String, uid: UInt, gid: UInt, homeDirectory: String) {
        self.username = username
        self.uid = uid
        self.gid = gid
        self.homeDirectory = homeDirectory
    }
}
