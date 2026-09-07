import AppKit
import Foundation
import ThrottleNetCore

/// Application delegate managing system lifecycle and teardown cleanup.
public final class AppDelegate: NSObject, NSApplicationDelegate {

  public func applicationDidFinishLaunching(_ notification: Notification) {
    // Register signal handlers for unexpected terminations
    signal(SIGINT) { _ in
      TrafficShaper.shared.resetAllSync()
      PrivilegeManager.shared.terminateHelper()
      exit(0)
    }
    signal(SIGTERM) { _ in
      TrafficShaper.shared.resetAllSync()
      PrivilegeManager.shared.terminateHelper()
      exit(0)
    }

    // Start background network sampling
    Task { @MainActor in
      NetworkMonitor.shared.startMonitoring()
    }

    // Apply Application Icon in Dock & Process Table
    if let icon = AppIconHelper.shared.appIcon {
      NSApplication.shared.applicationIconImage = icon
    }
  }

  public func applicationWillTerminate(_ notification: Notification) {
    // Synchronously flush all PF anchors, dummynet pipes, and connection states
    TrafficShaper.shared.resetAllSync()
    PrivilegeManager.shared.terminateHelper()
  }

  public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false  // Keep running in menu bar / background
  }
}
