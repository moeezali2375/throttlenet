import Combine
import Foundation
import SwiftUI

public enum ProcessFilterMode: String, CaseIterable, Identifiable {
  case all = "All"
  case active = "Active Traffic"
  case throttled = "Throttled"
  case autoRules = "Auto-Rules"
  case userApps = "User Apps"

  public var id: String { rawValue }
}

public enum ProcessSortField: String, CaseIterable, Identifiable {
  case downloadSpeed = "Download Speed"
  case uploadSpeed = "Upload Speed"
  case totalTraffic = "Total Data"
  case name = "Name"
  case pid = "PID"

  public var id: String { rawValue }
}

@MainActor
public final class DashboardViewModel: ObservableObject {
  @Published public var searchQuery: String = ""
  @Published public var filterMode: ProcessFilterMode = .all
  @Published public var sortField: ProcessSortField = .downloadSpeed
  @Published public var sortAscending: Bool = false

  @Published public var selectedProcessForThrottle: ProcessNetworkInfo? = nil
  @Published public var isShowingThrottleSheet: Bool = false
  @Published public var isShowingSavedRulesSheet: Bool = false
  @Published public var errorMessage: String? = nil
  @Published public var isShowingErrorAlert: Bool = false
  @Published public var isPerformingAction: Bool = false

  private var cancellables = Set<AnyCancellable>()
  public let monitor = NetworkMonitor.shared
  public let ruleStore = PersistentRuleStore.shared

  public init() {
    monitor.$processes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.objectWillChange.send()
      }
      .store(in: &cancellables)

    ruleStore.$rules
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.objectWillChange.send()
      }
      .store(in: &cancellables)
  }

  public var filteredAndSortedProcesses: [ProcessNetworkInfo] {
    var list = monitor.processes

    // 1. Filter by mode
    switch filterMode {
    case .all:
      break
    case .active:
      list = list.filter {
        $0.downloadBytesPerSec > 100 || $0.uploadBytesPerSec > 100 || $0.isThrottled
      }
    case .throttled:
      list = list.filter { $0.isThrottled }
    case .autoRules:
      list = list.filter { $0.hasPersistentRule }
    case .userApps:
      list = list.filter { !$0.isSystemProcess }
    }

    // 2. Filter by search query
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !query.isEmpty {
      list = list.filter {
        $0.displayName.lowercased().contains(query) || $0.rawName.lowercased().contains(query)
          || String($0.pid).contains(query)
          || ($0.bundleIdentifier?.lowercased().contains(query) ?? false)
      }
    }

    // 3. Sort
    list.sort { a, b in
      // Throttled / Auto-Rule processes prioritized slightly at the top if sorting by speed
      if a.isThrottled != b.isThrottled && filterMode != .throttled {
        return a.isThrottled && !b.isThrottled
      }

      let comparison: Bool
      switch sortField {
      case .downloadSpeed:
        comparison = a.downloadBytesPerSec < b.downloadBytesPerSec
      case .uploadSpeed:
        comparison = a.uploadBytesPerSec < b.uploadBytesPerSec
      case .totalTraffic:
        comparison = (a.totalBytesIn + a.totalBytesOut) < (b.totalBytesIn + b.totalBytesOut)
      case .name:
        comparison =
          a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
      case .pid:
        comparison = a.pid < b.pid
      }

      return sortAscending ? comparison : !comparison
    }

    return list
  }

  public func openThrottleSettings(for process: ProcessNetworkInfo) {
    selectedProcessForThrottle = process
    isShowingThrottleSheet = true
  }

  public func applyThrottle(
    for process: ProcessNetworkInfo,
    downloadLimitKBps: Double,
    uploadLimitKBps: Double,
    saveAsPersistentRule: Bool = true
  ) {
    isPerformingAction = true

    if saveAsPersistentRule {
      let rule = PersistentRule(
        processName: process.rawName,
        bundleIdentifier: process.bundleIdentifier,
        displayName: process.displayName,
        downloadLimitKBps: downloadLimitKBps,
        uploadLimitKBps: uploadLimitKBps,
        isEnabled: true,
        autoApplyOnLaunch: true,
        lastAppliedAt: Date()
      )
      ruleStore.saveRule(rule)
    } else {
      // Remove persistent rule if user explicitly unchecks remember
      ruleStore.deleteRule(forProcessName: process.rawName)
    }

    Task {
      do {
        try await TrafficShaper.shared.applyThrottle(
          for: process.pid,
          processName: process.rawName,
          downloadLimitKBps: downloadLimitKBps,
          uploadLimitKBps: uploadLimitKBps
        )
        await MainActor.run {
          self.monitor.sampleBandwidth()
          self.isPerformingAction = false
          self.isShowingThrottleSheet = false
        }
      } catch {
        await MainActor.run {
          self.errorMessage = error.localizedDescription
          self.isShowingErrorAlert = true
          self.isPerformingAction = false
        }
      }
    }
  }

  public func toggleThrottle(for process: ProcessNetworkInfo) {
    if process.isThrottled {
      removeThrottle(for: process)
    } else {
      openThrottleSettings(for: process)
    }
  }

  public func removeThrottle(for process: ProcessNetworkInfo, deletePersistentRule: Bool = true) {
    isPerformingAction = true
    if deletePersistentRule {
      ruleStore.deleteRule(forProcessName: process.rawName)
    }

    Task {
      do {
        try await TrafficShaper.shared.removeThrottle(for: process.pid)
        await MainActor.run {
          self.monitor.sampleBandwidth()
          self.isPerformingAction = false
        }
      } catch {
        await MainActor.run {
          self.errorMessage = error.localizedDescription
          self.isShowingErrorAlert = true
          self.isPerformingAction = false
        }
      }
    }
  }

  public func resetAllThrottles() {
    isPerformingAction = true
    Task {
      do {
        try await TrafficShaper.shared.resetAll()
        await MainActor.run {
          self.monitor.sampleBandwidth()
          self.isPerformingAction = false
        }
      } catch {
        await MainActor.run {
          self.errorMessage = error.localizedDescription
          self.isShowingErrorAlert = true
          self.isPerformingAction = false
        }
      }
    }
  }
}
