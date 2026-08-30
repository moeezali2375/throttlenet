import Foundation

/// Discovers open socket ports for active processes using lsof.
public final class SocketTracker {
    public static let shared = SocketTracker()
    
    private init() {}
    
    /// Returns the set of active local ports for a given PID.
    public func getLocalPorts(for pid: pid_t) -> Set<UInt16> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-i", "-a", "-p", "\(pid)", "-F", "n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            return parsePorts(from: output)
        } catch {
            return []
        }
    }
    
    /// Parses lsof -F n output to extract unique local ports.
    public func parsePorts(from lsofOutput: String) -> Set<UInt16> {
        var ports = Set<UInt16>()
        let lines = lsofOutput.split(separator: "\n")
        
        for line in lines {
            // lsof -F n outputs lines like "n192.168.1.5:54321->93.184.216.34:443" or "n[::1]:8080"
            guard line.hasPrefix("n") else { continue }
            let socketStr = line.dropFirst() // remove 'n'
            
            let localEndpoint: Substring
            if let arrowIndex = socketStr.range(of: "->") {
                localEndpoint = socketStr[..<arrowIndex.lowerBound]
            } else {
                localEndpoint = socketStr
            }
            
            // Port is the substring following the last colon
            if let lastColonIndex = localEndpoint.lastIndex(of: ":") {
                let portSubstring = localEndpoint[localEndpoint.index(after: lastColonIndex)...]
                if let port = UInt16(portSubstring), port > 0 {
                    ports.insert(port)
                }
            }
        }
        
        return ports
    }
}
