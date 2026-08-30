import Foundation

/// Manages macOS Dummynet (dnctl) and Packet Filter (pfctl) for bandwidth rate limiting.
public final class TrafficShaper {
    public static let shared = TrafficShaper()
    
    private var activeThrottles: [pid_t: ThrottleConfig] = [:]
    private var socketRefreshTimer: Timer?
    private let queue = DispatchQueue(label: "com.throttlenet.trafficshaper", qos: .userInitiated)
    
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
        
        var commands: [String] = []
        
        // 1. Configure dummynet pipes
        if downloadLimitKBps > 0 {
            commands.append("/usr/sbin/dnctl pipe \(downPipeId) config bw \(Int(downloadLimitKBps))Kbyte/s")
        } else {
            commands.append("/usr/sbin/dnctl pipe delete \(downPipeId) 2>/dev/null || true")
        }
        
        if uploadLimitKBps > 0 {
            commands.append("/usr/sbin/dnctl pipe \(upPipeId) config bw \(Int(uploadLimitKBps))Kbyte/s")
        } else {
            commands.append("/usr/sbin/dnctl pipe delete \(upPipeId) 2>/dev/null || true")
        }
        
        // 2. Fetch active ports for this process
        let ports = SocketTracker.shared.getLocalPorts(for: pid)
        
        // 3. Build PF anchor rules if ports exist
        if !ports.isEmpty {
            let portList = ports.map { String($0) }.joined(separator: " ")
            var pfRules: [String] = []
            
            if downloadLimitKBps > 0 {
                pfRules.append("dummynet in quick proto tcp from any to any port { \(portList) } pipe \(downPipeId)")
                pfRules.append("dummynet in quick proto udp from any to any port { \(portList) } pipe \(downPipeId)")
            }
            if uploadLimitKBps > 0 {
                pfRules.append("dummynet out quick proto tcp from any port { \(portList) } to any pipe \(upPipeId)")
                pfRules.append("dummynet out quick proto udp from any port { \(portList) } to any pipe \(upPipeId)")
            }
            
            if !pfRules.isEmpty {
                let ruleString = pfRules.joined(separator: "\\n")
                commands.append("printf \"\(ruleString)\\n\" | /sbin/pfctl -a throttlenet/\(pid) -f -")
            }
        }
        
        // 4. Ensure PF is enabled
        commands.append("/sbin/pfctl -e 2>/dev/null || true")
        
        try await PrivilegeManager.shared.executePrivileged(commands: commands)
        
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
        
        queue.sync {
            activeThrottles[pid] = config
        }
    }
    
    /// Remove bandwidth limits for a process.
    public func removeThrottle(for pid: pid_t) async throws {
        guard let config = queue.sync(execute: { activeThrottles[pid] }) else { return }
        
        var commands: [String] = []
        
        // Flush pf anchor for this pid
        commands.append("/sbin/pfctl -a throttlenet/\(pid) -F all 2>/dev/null || true")
        
        // Delete dnctl pipes
        if let downPipe = config.downloadPipeId {
            commands.append("/usr/sbin/dnctl pipe delete \(downPipe) 2>/dev/null || true")
        }
        if let upPipe = config.uploadPipeId {
            commands.append("/usr/sbin/dnctl pipe delete \(upPipe) 2>/dev/null || true")
        }
        
        try await PrivilegeManager.shared.executePrivileged(commands: commands)
        
        queue.sync {
            _ = activeThrottles.removeValue(forKey: pid)
        }
    }
    
    /// Resets all active throttles and clears all dummynet pipes and pf anchors.
    public func resetAll() async throws {
        let commands = [
            "/sbin/pfctl -a 'throttlenet/*' -F all 2>/dev/null || true",
            "/sbin/pfctl -a throttlenet -F all 2>/dev/null || true",
            "/usr/sbin/dnctl -q flush 2>/dev/null || true"
        ]
        
        try await PrivilegeManager.shared.executePrivileged(commands: commands)
        
        queue.sync {
            activeThrottles.removeAll()
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
    
    private func startSocketRefreshTimer() {
        socketRefreshTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.refreshActiveSockets()
        }
    }
    
    /// Periodically checks active throttles to update PF rules if the process opened new ports.
    private func refreshActiveSockets() {
        let currentThrottles = queue.sync { self.activeThrottles }
        guard !currentThrottles.isEmpty else { return }
        
        Task {
            for (pid, config) in currentThrottles {
                guard config.isEnabled else { continue }
                let ports = SocketTracker.shared.getLocalPorts(for: pid)
                guard !ports.isEmpty else { continue }
                
                let portList = ports.map { String($0) }.joined(separator: " ")
                var pfRules: [String] = []
                
                if let downPipe = config.downloadPipeId {
                    pfRules.append("dummynet in quick proto tcp from any to any port { \(portList) } pipe \(downPipe)")
                    pfRules.append("dummynet in quick proto udp from any to any port { \(portList) } pipe \(downPipe)")
                }
                if let upPipe = config.uploadPipeId {
                    pfRules.append("dummynet out quick proto tcp from any port { \(portList) } to any pipe \(upPipe)")
                    pfRules.append("dummynet out quick proto udp from any port { \(portList) } to any pipe \(upPipe)")
                }
                
                if !pfRules.isEmpty {
                    let ruleString = pfRules.joined(separator: "\\n")
                    let command = "printf \"\(ruleString)\\n\" | /sbin/pfctl -a throttlenet/\(pid) -f -"
                    _ = try? await PrivilegeManager.shared.executePrivileged(command: command)
                }
            }
        }
    }
}
