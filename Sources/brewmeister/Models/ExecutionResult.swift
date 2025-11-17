import Foundation

/// Result of executing a process
struct ExecutionResult {
    /// The exit code returned by the process
    let exitCode: Int

    /// Standard output captured during execution
    let stdout: String

    /// Standard error captured during execution
    let stderr: String

    /// Duration of the execution (if measured)
    let duration: TimeInterval?

    /// Whether the process succeeded (exit code 0)
    var succeeded: Bool {
        return exitCode == 0
    }

    /// Initialize an execution result
    init(exitCode: Int, stdout: String = "", stderr: String = "", duration: TimeInterval? = nil) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
    }
}
