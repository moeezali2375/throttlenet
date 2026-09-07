import AppKit
import Combine
import Foundation

/// Background monitoring service that continuously tracks per-process bandwidth consumption.
@MainActor
public final class NetworkMonitor: ObservableObject {
  public static let shared = NetworkMonitor()

  @Published public private(set) var processes: [ProcessNetworkInfo] = []
  @Published public private(set) var systemTotals = SystemNetworkTotals()
  @Published public private(set) var isMonitoring: Bool = false

  private var monitoringTimer: Timer?
  private var previousSamples: [pid_t: (bytesIn: UInt64, bytesOut: UInt64, timestamp: Date)] = [:]
  private var processHistory: [pid_t: (download: [Double], upload: [Double])] = [:]
  private var globalDownloadHistory: [Double] = []
  private var globalUploadHistory: [Double] = []

  private let maxHistoryLength = 20
  private var isSampling = false

  private init() {}

  public func startMonitoring(interval: TimeInterval = 1.0) {
    guard !isMonitoring else { return }
    isMonitoring = true

    // Take immediate initial sample
    sampleBandwidth()

    monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in
      Task { @MainActor [weak self] in
        self?.sampleBandwidth()
      }
    }
  }

  public func stopMonitoring() {
    monitoringTimer?.invalidate()
    monitoringTimer = nil
    isMonitoring = false
  }

  public func sampleBandwidth() {
    guard !isSampling else { return }
    isSampling = true

    Task.detached(priority: .userInitiated) { [weak self] in
      let rawData = await self?.fetchNettopSnapshot()
      let currentTime = Date()

      await MainActor.run { [weak self] in
        guard let self = self, let rawData = rawData else {
          self?.isSampling = false
          return
        }
        self.processSnapshot(rawData, timestamp: currentTime)
        self.isSampling = false
      }
    }
  }

  private nonisolated func fetchNettopSnapshot() async -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
    task.arguments = ["-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"]

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

  private func processSnapshot(_ rawOutput: String, timestamp: Date) {
    let lines = rawOutput.split(separator: "\n")
    var currentPids = Set<pid_t>()
    var updatedProcesses: [ProcessNetworkInfo] = []

    var totalDeltaIn: Double = 0
    var totalDeltaOut: Double = 0

    for line in lines {
      let cols = line.split(separator: ",", omittingEmptySubsequences: false)
      guard cols.count >= 3 else { continue }

      let procIdentifier = String(cols[0]).trimmingCharacters(in: .whitespaces)
      guard let bytesIn = UInt64(cols[1]), let bytesOut = UInt64(cols[2]) else {
        continue
      }

      // Format: "ProcessName.PID"
      guard let lastDotIndex = procIdentifier.lastIndex(of: ".") else { continue }
      let rawName = String(procIdentifier[..<lastDotIndex])
      let pidStr = String(procIdentifier[procIdentifier.index(after: lastDotIndex)...])
      guard let pid = pid_t(pidStr), pid > 0 else { continue }

      currentPids.insert(pid)

      var downloadSpeed: Double = 0
      var uploadSpeed: Double = 0

      if let prev = previousSamples[pid] {
        let timeDelta = timestamp.timeIntervalSince(prev.timestamp)
        if timeDelta > 0 {
          if bytesIn >= prev.bytesIn {
            downloadSpeed = Double(bytesIn - prev.bytesIn) / timeDelta
          }
          if bytesOut >= prev.bytesOut {
            uploadSpeed = Double(bytesOut - prev.bytesOut) / timeDelta
          }
        }
      }

      previousSamples[pid] = (bytesIn, bytesOut, timestamp)
      totalDeltaIn += downloadSpeed
      totalDeltaOut += uploadSpeed

      // Sparkline history maintenance
      var history = processHistory[pid] ?? (download: [], upload: [])
      history.download.append(downloadSpeed)
      history.upload.append(uploadSpeed)
      if history.download.count > maxHistoryLength {
        history.download.removeFirst(history.download.count - maxHistoryLength)
      }
      if history.upload.count > maxHistoryLength {
        history.upload.removeFirst(history.upload.count - maxHistoryLength)
      }
      processHistory[pid] = history

      // Metadata & Icon resolution
      let (displayName, bundleId, icon, isSystem) = ProcessInfoService.shared.resolveInfo(
        for: pid, rawName: rawName)
      let throttleConfig = TrafficShaper.shared.getThrottleConfig(for: pid)
      let persistentRule = PersistentRuleStore.shared.rule(
        forProcessName: rawName, bundleId: bundleId)

      // Auto-apply persistent rule if enabled and not already throttled
      if let rule = persistentRule, rule.isEnabled, rule.autoApplyOnLaunch, throttleConfig == nil {
        Task {
          try? await TrafficShaper.shared.applyThrottle(
            for: pid,
            processName: rawName,
            downloadLimitKBps: rule.downloadLimitKBps,
            uploadLimitKBps: rule.uploadLimitKBps
          )
        }
      }

      let info = ProcessNetworkInfo(
        pid: pid,
        rawName: rawName,
        displayName: displayName,
        bundleIdentifier: bundleId,
        icon: icon,
        downloadBytesPerSec: downloadSpeed,
        uploadBytesPerSec: uploadSpeed,
        totalBytesIn: bytesIn,
        totalBytesOut: bytesOut,
        downloadHistory: history.download,
        uploadHistory: history.upload,
        throttleConfig: throttleConfig,
        persistentRule: persistentRule,
        isSystemProcess: isSystem,
        lastSeen: timestamp,
        activeSocketCount: 0
      )

      updatedProcesses.append(info)
    }

    // Clean up stale PIDs
    for pid in previousSamples.keys where !currentPids.contains(pid) {
      previousSamples.removeValue(forKey: pid)
      processHistory.removeValue(forKey: pid)
      ProcessInfoService.shared.clearCache(for: pid)
    }

    // Update global history
    globalDownloadHistory.append(totalDeltaIn)
    globalUploadHistory.append(totalDeltaOut)
    if globalDownloadHistory.count > maxHistoryLength {
      globalDownloadHistory.removeFirst(globalDownloadHistory.count - maxHistoryLength)
    }
    if globalUploadHistory.count > maxHistoryLength {
      globalUploadHistory.removeFirst(globalUploadHistory.count - maxHistoryLength)
    }

    let throttledCount = updatedProcesses.filter { $0.isThrottled }.count

    var totals = SystemNetworkTotals(
      totalDownloadBytesPerSec: totalDeltaIn,
      totalUploadBytesPerSec: totalDeltaOut,
      totalActiveProcesses: updatedProcesses.count,
      throttledProcessesCount: throttledCount
    )
    totals.totalDownloadHistory = globalDownloadHistory
    totals.totalUploadHistory = globalUploadHistory

    self.systemTotals = totals
    self.processes = updatedProcesses
  }
}
