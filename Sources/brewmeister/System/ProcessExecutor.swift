import Foundation

/// Executes external processes with various configurations
class ProcessExecutor {
    /// Execute a command and return the result
    /// - Parameters:
    ///   - command: Array of command and arguments (e.g., ["/usr/bin/ls", "-la"])
    ///   - captureOutput: Whether to capture stdout/stderr or stream to parent
    ///   - workingDirectory: Optional working directory
    /// - Returns: Execution result with exit code and output
    static func execute(
        _ command: [String],
        captureOutput: Bool = false,
        workingDirectory: String? = nil
    ) throws -> ExecutionResult {
        guard !command.isEmpty else {
            throw BrewmeisterError.processExecutionFailed(command: "empty", exitCode: -1)
        }

        let startTime = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        if captureOutput {
            process.standardOutput = outputPipe
            process.standardError = errorPipe
        } else {
            // Stream directly to parent's stdout/stderr
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
        }

        // Capture stdin to prevent hanging on prompts
        process.standardInput = Pipe()

        do {
            try process.run()
        } catch {
            Logger.error("Failed to launch process: \(command[0])")
            Logger.error("Error: \(error.localizedDescription)")
            throw BrewmeisterError.processExecutionFailed(
                command: command.joined(separator: " "),
                exitCode: -1
            )
        }

        var stdout = ""
        var stderr = ""

        // Read output asynchronously to prevent deadlock
        // Reading after waitUntilExit() can cause deadlock if pipe buffer fills
        if captureOutput {
            var outputData = Data()
            var errorData = Data()

            let outputQueue = DispatchQueue(label: "brewmeister.stdout")
            let errorQueue = DispatchQueue(label: "brewmeister.stderr")
            let outputGroup = DispatchGroup()

            outputGroup.enter()
            outputQueue.async {
                outputData = (try? outputPipe.fileHandleForReading.readToEnd()) ?? Data()
                outputGroup.leave()
            }

            outputGroup.enter()
            errorQueue.async {
                errorData = (try? errorPipe.fileHandleForReading.readToEnd()) ?? Data()
                outputGroup.leave()
            }

            process.waitUntilExit()
            outputGroup.wait()

            stdout = String(data: outputData, encoding: .utf8) ?? ""
            stderr = String(data: errorData, encoding: .utf8) ?? ""
        } else {
            process.waitUntilExit()
        }

        let duration = Date().timeIntervalSince(startTime)
        let exitCode = Int(process.terminationStatus)

        return ExecutionResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            duration: duration
        )
    }

    /// Execute a command as a different user using sudo
    /// - Parameters:
    ///   - username: Username to execute as
    ///   - command: Array of command and arguments
    ///   - captureOutput: Whether to capture stdout/stderr
    ///   - loginShell: Whether to use login shell (-i flag)
    ///   - homeDirectory: Optional HOME directory to set
    /// - Returns: Execution result
    static func executeAsUser(
        username: String,
        command: [String],
        captureOutput: Bool = false,
        loginShell: Bool = true,
        homeDirectory: String? = nil
    ) throws -> ExecutionResult {
        guard !command.isEmpty else {
            throw BrewmeisterError.processExecutionFailed(command: "empty", exitCode: -1)
        }

        // Build sudo command with HOME override if needed
        var sudoArgs = ["-u", username]

        // Set HOME environment variable to writable location if specified
        if let home = homeDirectory {
            sudoArgs.append(contentsOf: ["HOME=\(home)"])
        }

        if loginShell {
            sudoArgs.append("-i")
        }
        sudoArgs.append(contentsOf: command)

        let sudoCommand = ["/usr/bin/sudo"] + sudoArgs

        Logger.debug("Executing as \(username): \(command.joined(separator: " "))")

        return try execute(sudoCommand, captureOutput: captureOutput)
    }

    /// Check if sudo access is available without password
    /// - Returns: True if sudo is available without password prompt
    static func haveSudoAccess() -> Bool {
        do {
            let result = try execute(
                ["/usr/bin/sudo", "-n", "true"],
                captureOutput: true
            )
            return result.succeeded
        } catch {
            return false
        }
    }

    /// Execute a shell command (wraps command in shell)
    /// - Parameters:
    ///   - shellCommand: Shell command string
    ///   - captureOutput: Whether to capture output
    /// - Returns: Execution result
    static func executeShell(
        _ shellCommand: String,
        captureOutput: Bool = false
    ) throws -> ExecutionResult {
        return try execute(
            ["/bin/bash", "-c", shellCommand],
            captureOutput: captureOutput
        )
    }
}
