import Foundation

/// Manages macOS Dummynet (dnctl) and Packet Filter (pfctl) for bandwidth rate limiting.
public final class TrafficShaper {
  public static let shared = TrafficShaper()

  private var activeThrottles: [pid_t: ThrottleConfig] = [:]
  private var lastConfiguredPorts: [pid_t: Set<UInt16>] = [:]
  private var socketRefreshTimer: Timer?
  private let queue = DispatchQueue(label: "com.throttlenet.trafficshaper", qos: .userInitiated)

  /// Unified anchor registered in macOS /etc/pf.conf ("com.apple/*")
  private let anchorName = "com.apple/throttlenet"

  private init() {
    startSocketRefreshTimer()
  }

  deinit {
    socketRefreshTimer?.invalidate()
  }

  /// Apply or update bandwidth limits for a process.
  public func applyThrottle(
    for pid: pid_t,
    processName: String,
    downloadLimitKBps: Double,
    uploadLimitKBps: Double
  ) async throws {
    let downPipeId = 1000 + Int(pid % 25000) * 2
    let upPipeId = downPipeId + 1

    let config = ThrottleConfig(
      pid: pid,
      processName: processName,
      isEnabled: true,
      downloadLimitKBps: downloadLimitKBps,
      uploadLimitKBps: uploadLimitKBps,
      downloadPipeId: downloadLimitKBps > 0 ? downPipeId : nil,
      uploadPipeId: uploadLimitKBps > 0 ? upPipeId : nil,
      lastUpdated: Date()
    )

    let ports = SocketTracker.shared.getLocalPorts(for: pid)

    queue.sync {
      activeThrottles[pid] = config
      lastConfiguredPorts[pid] = ports
    }

    try await rebuildAllRulesAndPipes()
  }

  /// Remove bandwidth limits for a process and immediately reset its network state.
  public func removeThrottle(for pid: pid_t) async throws {
    let (removedConfig, removedPorts) = queue.sync { () -> (ThrottleConfig?, Set<UInt16>?) in
      let c = activeThrottles.removeValue(forKey: pid)
      let p = lastConfiguredPorts.removeValue(forKey: pid)
      return (c, p)
    }

    guard removedConfig != nil else { return }

    // Delete dnctl pipes for this pid
    var commands: [String] = []
    if let downPipe = removedConfig?.downloadPipeId {
      commands.append("/usr/sbin/dnctl pipe delete \(downPipe) 2>/dev/null || true")
    }
    if let upPipe = removedConfig?.uploadPipeId {
      commands.append("/usr/sbin/dnctl pipe delete \(upPipe) 2>/dev/null || true")
    }

    // Kill state entries for the unthrottled ports so active connections immediately burst to full speed
    if let ports = removedPorts, !ports.isEmpty {
      for port in ports {
        commands.append("/sbin/pfctl -k 0.0.0.0/0 -k 0.0.0.0/0:port=\(port) 2>/dev/null || true")
      }
    }

    let remaining = queue.sync { activeThrottles }
    if remaining.isEmpty {
      commands.append("/sbin/pfctl -a \(anchorName) -F all 2>/dev/null || true")
      commands.append("/usr/sbin/dnctl -q flush 2>/dev/null || true")
      commands.append("/sbin/pfctl -F states 2>/dev/null || true")
      try await PrivilegeManager.shared.executePrivileged(commands: commands)
    } else {
      try await PrivilegeManager.shared.executePrivileged(commands: commands)
      try await rebuildAllRulesAndPipes()
    }
  }

  /// Resets all active throttles and flushes all dummynet pipes and pf anchors/states.
  /// If `deletePersistentRules` is true (default), all saved auto-rules are also cleared.
  public func resetAll(deletePersistentRules: Bool = true) async throws {
    if deletePersistentRules {
      PersistentRuleStore.shared.deleteAllRules()
    }

    queue.sync {
      activeThrottles.removeAll()
      lastConfiguredPorts.removeAll()
    }

    let commands = [
      "/sbin/pfctl -a \(anchorName) -F all 2>/dev/null || true",
      "/usr/sbin/dnctl -q flush 2>/dev/null || true",
      "/sbin/pfctl -F states 2>/dev/null || true",
    ]

    try await PrivilegeManager.shared.executePrivileged(commands: commands)

    queue.sync {
      activeThrottles.removeAll()
      lastConfiguredPorts.removeAll()
    }
  }

  /// Synchronously resets all rules (used during app exit).
  public func resetAllSync() {
    let command =
      "/sbin/pfctl -a \(anchorName) -F all 2>/dev/null || true; /usr/sbin/dnctl -q flush 2>/dev/null || true; /sbin/pfctl -F states 2>/dev/null || true"
    PrivilegeManager.shared.executePrivilegedSync(command: command)

    queue.sync {
      activeThrottles.removeAll()
      lastConfiguredPorts.removeAll()
    }
  }

  /// Check if a PID is currently throttled.
  public func getThrottleConfig(for pid: pid_t) -> ThrottleConfig? {
    return queue.sync { activeThrottles[pid] }
  }

  /// Returns all currently active throttle configurations.
  public var allActiveThrottles: [ThrottleConfig] {
    return queue.sync { Array(activeThrottles.values) }
  }

  /// Re-evaluates and writes all active dummynet pipes and packet filter rules in one atomic pass.
  private func rebuildAllRulesAndPipes() async throws {
    let throttles = queue.sync { activeThrottles }

    if throttles.isEmpty {
      let commands = [
        "/sbin/pfctl -a \(anchorName) -F all 2>/dev/null || true",
        "/usr/sbin/dnctl -q flush 2>/dev/null || true",
        "/sbin/pfctl -F states 2>/dev/null || true",
      ]
      try await PrivilegeManager.shared.executePrivileged(commands: commands)
      return
    }

    var commands: [String] = []
    var allPfRules: [String] = []

    for (pid, config) in throttles {
      guard config.isEnabled else { continue }

      // 1. Configure pipes
      if let downPipe = config.downloadPipeId, config.downloadLimitKBps > 0 {
        commands.append(
          "/usr/sbin/dnctl pipe \(downPipe) config bw \(Int(config.downloadLimitKBps))Kbyte/s")
      }
      if let upPipe = config.uploadPipeId, config.uploadLimitKBps > 0 {
        commands.append(
          "/usr/sbin/dnctl pipe \(upPipe) config bw \(Int(config.uploadLimitKBps))Kbyte/s")
      }

      // 2. Resolve ports
      let ports = SocketTracker.shared.getLocalPorts(for: pid)
      if !ports.isEmpty {
        let portList = ports.map { String($0) }.joined(separator: " ")
        if let downPipe = config.downloadPipeId, config.downloadLimitKBps > 0 {
          allPfRules.append(
            "dummynet in quick proto tcp from any to any port { \(portList) } pipe \(downPipe)")
          allPfRules.append(
            "dummynet in quick proto udp from any to any port { \(portList) } pipe \(downPipe)")
        }
        if let upPipe = config.uploadPipeId, config.uploadLimitKBps > 0 {
          allPfRules.append(
            "dummynet out quick proto tcp from any port { \(portList) } to any pipe \(upPipe)")
          allPfRules.append(
            "dummynet out quick proto udp from any port { \(portList) } to any pipe \(upPipe)")
        }
      }
    }

    // 3. Load rules into anchor
    if !allPfRules.isEmpty {
      let ruleString = allPfRules.joined(separator: "\\n")
      commands.append("printf \"\(ruleString)\\n\" | /sbin/pfctl -a \(anchorName) -f -")
    } else {
      commands.append("/sbin/pfctl -a \(anchorName) -F all 2>/dev/null || true")
    }

    commands.append("/sbin/pfctl -e 2>/dev/null || true")

    try await PrivilegeManager.shared.executePrivileged(commands: commands)
  }

  private func startSocketRefreshTimer() {
    socketRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
      [weak self] _ in
      self?.refreshActiveSockets()
    }
  }

  /// Periodically checks active throttles to update PF rules if any process opened new ports.
  private func refreshActiveSockets() {
    let (currentThrottles, currentLastPorts) = queue.sync {
      (self.activeThrottles, self.lastConfiguredPorts)
    }
    guard !currentThrottles.isEmpty else { return }

    Task {
      var hasPortChanges = false

      for (pid, config) in currentThrottles {
        guard config.isEnabled else { continue }
        let ports = SocketTracker.shared.getLocalPorts(for: pid)
        guard !ports.isEmpty else { continue }

        if let lastPorts = currentLastPorts[pid], lastPorts == ports {
          continue
        }

        self.queue.sync {
          self.lastConfiguredPorts[pid] = ports
        }
        hasPortChanges = true
      }

      if hasPortChanges {
        try? await self.rebuildAllRulesAndPipes()
      }
    }
  }
}
