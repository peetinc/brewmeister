import XCTest
@testable import brewmeister

final class ExecutionResultTests: XCTestCase {
    func testExecutionResultInit() {
        let result = ExecutionResult(
            exitCode: 0,
            stdout: "Hello, World!",
            stderr: "",
            duration: 1.5
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "Hello, World!")
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(result.duration, 1.5)
    }

    func testExecutionResultDefaultValues() {
        let result = ExecutionResult(exitCode: 0)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(result.stderr, "")
        XCTAssertNil(result.duration)
    }

    func testSucceededPropertyWithZeroExitCode() {
        let result = ExecutionResult(exitCode: 0)
        XCTAssertTrue(result.succeeded)
    }

    func testSucceededPropertyWithNonZeroExitCode() {
        let result = ExecutionResult(exitCode: 1)
        XCTAssertFalse(result.succeeded)

        let result2 = ExecutionResult(exitCode: 127)
        XCTAssertFalse(result2.succeeded)
    }

    func testExecutionResultWithStdout() {
        let result = ExecutionResult(
            exitCode: 0,
            stdout: "Line 1\nLine 2\nLine 3"
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdout, "Line 1\nLine 2\nLine 3")
    }

    func testExecutionResultWithStderr() {
        let result = ExecutionResult(
            exitCode: 1,
            stdout: "",
            stderr: "Error: Something went wrong"
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.stderr, "Error: Something went wrong")
    }

    func testExecutionResultWithDuration() {
        let result = ExecutionResult(
            exitCode: 0,
            duration: 2.5
        )

        XCTAssertEqual(result.duration, 2.5)
    }
}
