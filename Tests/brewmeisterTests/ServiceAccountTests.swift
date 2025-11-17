import XCTest
@testable import brewmeister

final class ServiceAccountTests: XCTestCase {
    func testServiceAccountInit() {
        let account = ServiceAccount(
            username: "_brewmeister",
            uid: 901,
            gid: 901,
            homeDirectory: "/Library/Management/Users/_brewmeister"
        )

        XCTAssertEqual(account.username, "_brewmeister")
        XCTAssertEqual(account.uid, 901)
        XCTAssertEqual(account.gid, 901)
        XCTAssertEqual(account.homeDirectory, "/Library/Management/Users/_brewmeister")
    }

    func testServiceAccountEquality() {
        let account1 = ServiceAccount(
            username: "_brewmeister",
            uid: 901,
            gid: 901,
            homeDirectory: "/Library/Management/Users/_brewmeister"
        )

        let account2 = ServiceAccount(
            username: "_brewmeister",
            uid: 901,
            gid: 901,
            homeDirectory: "/Library/Management/Users/_brewmeister"
        )

        XCTAssertEqual(account1.username, account2.username)
        XCTAssertEqual(account1.uid, account2.uid)
        XCTAssertEqual(account1.gid, account2.gid)
        XCTAssertEqual(account1.homeDirectory, account2.homeDirectory)
    }

    func testServiceAccountWithDifferentUIDGID() {
        let account = ServiceAccount(
            username: "_testuser",
            uid: 950,
            gid: 80,  // admin group
            homeDirectory: "/var/empty"
        )

        XCTAssertEqual(account.uid, 950)
        XCTAssertEqual(account.gid, 80)
    }
}
