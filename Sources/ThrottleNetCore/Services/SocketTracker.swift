import Foundation

/// Discovers open socket ports for active processes using nettop and lsof.
public final class SocketTracker {
  public static let shared = SocketTracker()

  private init() {}

  /// Returns the set of active local ports for a given PID.
  public func getLocalPorts(for pid: pid_t) -> Set<UInt16> {
    var allPorts = Set<UInt16>()

    // 1. Primary Method: nettop (captures Network.framework, Skywalk, TCP, UDP, QUIC, and standard sockets)
    if let nettopOutput = runNettop(for: pid) {
      let nettopPorts = parseNettopPorts(from: nettopOutput)
      allPorts.formUnion(nettopPorts)
    }

    // 2. Secondary Method: lsof (captures standard POSIX BSD sockets)
    if let lsofOutput = runLsof(for: pid) {
      let lsofPorts = parsePorts(from: lsofOutput)
      allPorts.formUnion(lsofPorts)
    }

    return allPorts
  }

  private func runNettop(for pid: pid_t) -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
    task.arguments = ["-p", "\(pid)", "-n", "-L", "1"]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice

    do {
      try task.run()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      task.waitUntilExit()
      return String(data: data, encoding: .utf8)
    } catch {
      return nil
    }
  }

  private func runLsof(for pid: pid_t) -> String? {
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
      return String(data: data, encoding: .utf8)
    } catch {
      return nil
    }
  }

  /// Parses nettop -p <pid> -n -L 1 output to extract local ports for TCP, UDP, and QUIC.
  public func parseNettopPorts(from output: String) -> Set<UInt16> {
    var ports = Set<UInt16>()
    let lines = output.split(separator: "\n")

    for line in lines {
      let cols = line.split(separator: ",", omittingEmptySubsequences: false)
      guard cols.count > 1 else { continue }
      let flow = cols[1].trimmingCharacters(in: .whitespaces)

      // Format examples:
      // "tcp6 2407:aa80:...56332<->2406:da60:...443"
      // "quic4 192.168.0.101:51126<->17.248.224.13:443"
      // "tcp4 192.168.100.118:52661<->64.233.184.188:5228"
      guard let arrowIndex = flow.range(of: "<->") else { continue }
      let localPart = flow[..<arrowIndex.lowerBound]

      // Determine the separator closest to the end (. or :)
      let lastDot = localPart.lastIndex(of: ".")
      let lastColon = localPart.lastIndex(of: ":")

      let lastSeparatorIndex: String.Index?
      if let dot = lastDot, let colon = lastColon {
        lastSeparatorIndex = max(dot, colon)
      } else {
        lastSeparatorIndex = lastDot ?? lastColon
      }

      if let sep = lastSeparatorIndex {
        let portStr = localPart[localPart.index(after: sep)...]
        if let port = UInt16(portStr), port > 0 {
          ports.insert(port)
        }
      }
    }

    return ports
  }

  /// Parses lsof -F n output to extract unique local ports.
  public func parsePorts(from lsofOutput: String) -> Set<UInt16> {
    var ports = Set<UInt16>()
    let lines = lsofOutput.split(separator: "\n")

    for line in lines {
      guard line.hasPrefix("n") else { continue }
      let socketStr = line.dropFirst()  // remove 'n'

      let localEndpoint: Substring
      if let arrowIndex = socketStr.range(of: "->") {
        localEndpoint = socketStr[..<arrowIndex.lowerBound]
      } else {
        localEndpoint = socketStr
      }

      let lastDot = localEndpoint.lastIndex(of: ".")
      let lastColon = localEndpoint.lastIndex(of: ":")

      let lastSeparatorIndex: Substring.Index?
      if let dot = lastDot, let colon = lastColon {
        lastSeparatorIndex = max(dot, colon)
      } else {
        lastSeparatorIndex = lastDot ?? lastColon
      }

      if let sep = lastSeparatorIndex {
        let portSubstring = localEndpoint[localEndpoint.index(after: sep)...]
        if let port = UInt16(portSubstring), port > 0 {
          ports.insert(port)
        }
      }
    }

    return ports
  }
}
