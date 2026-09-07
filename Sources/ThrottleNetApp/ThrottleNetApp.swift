import AppKit
import SwiftUI
import ThrottleNetCore

@main
struct ThrottleNetApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var monitor = NetworkMonitor.shared

  var body: some Scene {
    // Main Dashboard Window
    WindowGroup("ThrottleNet - Bandwidth Manager") {
      MainDashboardView()
        .frame(minWidth: 700, minHeight: 500)
    }
    .windowResizability(.contentSize)
    .windowStyle(.titleBar)
    .commands {
      CommandGroup(replacing: .newItem) {}  // Remove 'New Window'
      CommandMenu("Bandwidth") {
        Button("Refresh Rates") {
          monitor.sampleBandwidth()
        }
        .keyboardShortcut("r", modifiers: .command)

        Divider()

        Button("Reset All Throttles") {
          monitor.clearAllThrottlesLocally()
          PersistentRuleStore.shared.deleteAllRules()
          Task {
            try? await TrafficShaper.shared.resetAll(deletePersistentRules: false)
            monitor.sampleBandwidth()
          }
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])
      }
    }

    // Menu Bar Status Item
    MenuBarExtra {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          AppIconView(size: 20)
          Text("ThrottleNet")
            .font(.headline)
        }

        let totals = monitor.systemTotals
        Text("Download: \(totals.formattedDownloadSpeed)")
        Text("Upload: \(totals.formattedUploadSpeed)")

        if totals.throttledProcessesCount > 0 {
          Text("\(totals.throttledProcessesCount) process(es) throttled")
            .foregroundColor(.orange)
        }

        Divider()

        Button("Open Dashboard") {
          NSApp.activate(ignoringOtherApps: true)
          if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
          }
        }

        if totals.throttledProcessesCount > 0 {
          Button("Reset All Limits") {
            monitor.clearAllThrottlesLocally()
            PersistentRuleStore.shared.deleteAllRules()
            Task {
              try? await TrafficShaper.shared.resetAll(deletePersistentRules: false)
              monitor.sampleBandwidth()
            }
          }
        }

        Divider()

        Button("Quit ThrottleNet") {
          NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
      }
    } label: {
      HStack(spacing: 4) {
        Image(
          systemName: monitor.systemTotals.throttledProcessesCount > 0
            ? "gauge.with.needle.fill" : "network")
        if monitor.systemTotals.throttledProcessesCount > 0 {
          Text("\(monitor.systemTotals.throttledProcessesCount)")
            .font(.system(size: 11, weight: .bold))
        }
      }
    }
  }
}
