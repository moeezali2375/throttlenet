import AppKit
import Foundation

/// Manages privileged execution of macOS traffic shaping commands with a single administrator prompt.
public final class PrivilegeManager: @unchecked Sendable {
  public static let shared = PrivilegeManager()

  private let fifoInPath = "/tmp/throttlenet_in.fifo"
  private let fifoOutPath = "/tmp/throttlenet_out.fifo"
  private let workerScriptPath = "/tmp/throttlenet_worker.sh"

  private var isHelperActive = false
  private let lock = NSLock()

  private var isRoot: Bool {
    return geteuid() == 0
  }

  private init() {}

  public enum PrivilegeError: LocalizedError {
    case executionFailed(String)
    case permissionDenied
    case helperLaunchFailed

    public var errorDescription: String? {
      switch self {
      case .executionFailed(let msg): return "Command execution failed: \(msg)"
      case .permissionDenied: return "Administrator permission was denied."
      case .helperLaunchFailed: return "Failed to start privileged helper daemon."
      }
    }
  }

  /// Executes a batch of commands with administrator privileges.
  @discardableResult
  public func executePrivileged(commands: [String]) async throws -> String {
    let combinedCommand = commands.joined(separator: " && ")
    return try await executePrivileged(command: combinedCommand)
  }

  /// Executes a command with root privileges via the persistent helper.
  @discardableResult
  public func executePrivileged(command: String) async throws -> String {
    if isRoot {
      return try runDirectShell(command: command)
    }

    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else {
          continuation.resume(throwing: PrivilegeError.executionFailed("Manager deallocated"))
          return
        }

        self.lock.lock()
        defer { self.lock.unlock() }

        do {
          try self.ensureHelperRunning()
          try self.sendCommandToHelper(command)
          continuation.resume(returning: "OK")
        } catch {
          self.isHelperActive = false
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Synchronously executes a command with root privileges (used during app termination).
  @discardableResult
  public func executePrivilegedSync(command: String) -> Bool {
    if isRoot {
      return (try? runDirectShell(command: command)) != nil
    }

    lock.lock()
    defer { lock.unlock() }

    guard isHelperActive else { return false }
    do {
      try sendCommandToHelper(command, timeoutSeconds: 1.0)
      return true
    } catch {
      return false
    }
  }

  /// Ensures the background root worker is running (prompts password only once).
  private func ensureHelperRunning() throws {
    if isHelperActive && checkHelperAlive() {
      return
    }

    // Clean up old FIFOs
    unlink(fifoInPath)
    unlink(fifoOutPath)

    // Create fresh FIFOs with readable/writable permissions
    guard mkfifo(fifoInPath, 0o666) == 0, mkfifo(fifoOutPath, 0o666) == 0 else {
      throw PrivilegeError.executionFailed("Failed to create IPC FIFOs")
    }

    // Set loose permissions on FIFOs so standard user and root can both read/write
    chmod(fifoInPath, 0o666)
    chmod(fifoOutPath, 0o666)

    // Write the worker shell script
    let workerScript = """
      #!/bin/bash
      FIFO_IN="\(fifoInPath)"
      FIFO_OUT="\(fifoOutPath)"

      while true; do
          if read -r line < "$FIFO_IN"; then
              if [ "$line" = "PING" ]; then
                  echo "PONG" > "$FIFO_OUT"
              elif [ "$line" = "EXIT_WORKER" ]; then
                  /sbin/pfctl -a com.apple/throttlenet -F all 2>/dev/null
                  /usr/sbin/dnctl -q flush 2>/dev/null
                  /sbin/pfctl -F states 2>/dev/null
                  echo "OK" > "$FIFO_OUT"
                  exit 0
              else
                  eval "$line" >/dev/null 2>&1
                  echo "OK" > "$FIFO_OUT"
              fi
          fi
      done
      """

    try workerScript.write(toFile: workerScriptPath, atomically: true, encoding: .utf8)
    chmod(workerScriptPath, 0o755)

    // Launch worker with administrator privileges ONCE
    let scriptSource =
      "do shell script \"bash \(workerScriptPath) >/dev/null 2>&1 &\" with administrator privileges"

    var errorDict: NSDictionary?
    guard let script = NSAppleScript(source: scriptSource) else {
      throw PrivilegeError.helperLaunchFailed
    }

    _ = script.executeAndReturnError(&errorDict)

    if let error = errorDict {
      let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
      if errorNumber == -128 {
        throw PrivilegeError.permissionDenied
      }
      let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
      throw PrivilegeError.executionFailed(errorMessage)
    }

    // Wait for helper to become ready (max 2 seconds)
    var isReady = false
    for _ in 0..<20 {
      usleep(100_000)  // 100ms
      if checkHelperAlive() {
        isReady = true
        break
      }
    }

    guard isReady else {
      throw PrivilegeError.helperLaunchFailed
    }

    isHelperActive = true
  }

  private func checkHelperAlive() -> Bool {
    do {
      try sendCommandToHelper("PING", timeoutSeconds: 0.3)
      return true
    } catch {
      return false
    }
  }

  private func sendCommandToHelper(_ command: String, timeoutSeconds: TimeInterval = 2.0) throws {
    // Open FIFO_IN for writing
    guard let inHandle = FileHandle(forWritingAtPath: fifoInPath) else {
      throw PrivilegeError.executionFailed("Failed to open FIFO for writing")
    }

    let commandData = (command + "\n").data(using: .utf8)!
    try inHandle.write(contentsOf: commandData)
    try inHandle.close()

    // Open FIFO_OUT for reading with timeout
    guard let outHandle = FileHandle(forReadingAtPath: fifoOutPath) else {
      throw PrivilegeError.executionFailed("Failed to open FIFO for reading")
    }

    let responseData = outHandle.readData(ofLength: 64)
    try outHandle.close()

    guard
      let response = String(data: responseData, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines),
      !response.isEmpty
    else {
      throw PrivilegeError.executionFailed("No response from privileged helper")
    }
  }

  private func runDirectShell(command: String) throws -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments = ["-c", command]

    let pipe = Pipe()
    let errPipe = Pipe()
    task.standardOutput = pipe
    task.standardError = errPipe

    try task.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()

    if task.terminationStatus != 0 {
      let errMsg = String(data: errData, encoding: .utf8) ?? "Exit code \(task.terminationStatus)"
      throw PrivilegeError.executionFailed(errMsg)
    }

    return String(data: data, encoding: .utf8) ?? ""
  }

  /// Terminates the background helper worker and flushes kernel rules and states.
  public func terminateHelper() {
    lock.lock()
    defer { lock.unlock() }

    if isHelperActive {
      try? sendCommandToHelper("EXIT_WORKER", timeoutSeconds: 1.0)
      isHelperActive = false
    }

    unlink(fifoInPath)
    unlink(fifoOutPath)
    unlink(workerScriptPath)
  }
}
