import Foundation

/// Manages privileged execution of macOS traffic shaping commands (pfctl & dnctl).
public final class PrivilegeManager {
    public static let shared = PrivilegeManager()
    
    private var isRoot: Bool {
        return geteuid() == 0
    }
    
    private init() {}
    
    public enum PrivilegeError: LocalizedError {
        case executionFailed(String)
        case permissionDenied
        
        public var errorDescription: String? {
            switch self {
            case .executionFailed(let msg): return "Command execution failed: \(msg)"
            case .permissionDenied: return "Administrator permission was denied."
            }
        }
    }
    
    /// Executes a batch of commands with administrator privileges.
    @discardableResult
    public func executePrivileged(commands: [String]) async throws -> String {
        let combinedCommand = commands.joined(separator: " && ")
        return try await executePrivileged(command: combinedCommand)
    }
    
    /// Executes a single command with root privileges.
    @discardableResult
    public func executePrivileged(command: String) async throws -> String {
        if isRoot {
            // Already running as root, execute directly via /bin/zsh
            return try runDirectShell(command: command)
        } else {
            // Execute using AppleScript with administrator privileges prompt
            return try runAppleScriptAdmin(command: command)
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
    
    private func runAppleScriptAdmin(command: String) throws -> String {
        // Escape quotes and backslashes for AppleScript
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let scriptSource = "do shell script \"\(escapedCommand)\" with administrator privileges"
        
        var errorDict: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            throw PrivilegeError.executionFailed("Failed to initialize NSAppleScript")
        }
        
        let outputDescriptor = script.executeAndReturnError(&errorDict)
        
        if let error = errorDict {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
            if errorNumber == -128 { // User clicked cancel
                throw PrivilegeError.permissionDenied
            }
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw PrivilegeError.executionFailed(errorMessage)
        }
        
        return outputDescriptor.stringValue ?? ""
    }
}
