import Foundation
import AppKit
import ThrottleNetCore

/// Application delegate managing system lifecycle and teardown cleanup.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Start background network sampling
        Task { @MainActor in
            NetworkMonitor.shared.startMonitoring()
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        // Clean up any active PF anchors and Dummynet pipes on exit
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            try? await TrafficShaper.shared.resetAll()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.5)
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar / background
    }
}
