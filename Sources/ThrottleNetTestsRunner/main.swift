import Foundation
import ThrottleNetCore

print("🧪 Running ThrottleNet Test Suite...")

// Test 1: SpeedUnit Formatting
print("• Testing SpeedUnit Formatting...")
assert(SpeedUnit.format(bytesPerSecond: 0) == "0 KB/s", "Failed 0 B/s")
assert(SpeedUnit.format(bytesPerSecond: 500) == "500 B/s", "Failed 500 B/s")
assert(SpeedUnit.format(bytesPerSecond: 1024) == "1.0 KB/s", "Failed 1.0 KB/s")
assert(SpeedUnit.format(bytesPerSecond: 500 * 1024) == "500.0 KB/s", "Failed 500 KB/s")
assert(SpeedUnit.format(bytesPerSecond: 1.5 * 1024 * 1024) == "1.50 MB/s", "Failed 1.5 MB/s")
assert(
  SpeedUnit.format(bytesPerSecond: 2.25 * 1024 * 1024 * 1024) == "2.25 GB/s", "Failed 2.25 GB/s")
print("  ✅ SpeedUnit tests passed!")

// Test 2: Total Bytes Formatting
print("• Testing Total Bytes Formatting...")
assert(SpeedUnit.formatTotal(bytes: 512) == "512 B")
assert(SpeedUnit.formatTotal(bytes: 1024 * 50) == "50.0 KB")
assert(SpeedUnit.formatTotal(bytes: 1024 * 1024 * 25) == "25.00 MB")
assert(SpeedUnit.formatTotal(bytes: UInt64(1024 * 1024 * 1024 * 3.5)) == "3.50 GB")
print("  ✅ Total Bytes tests passed!")

// Test 3: Socket Tracker Parsing (lsof & nettop)
print("• Testing Socket Tracker Parsing...")
let sampleLsofOutput = """
  p21471
  f22
  n[2407:aa80:116:4566:e4a0:dc16:5d52:2a80]:53086->[2a00:1450:4019:804::200e]:443
  f29
  n192.168.100.118:52661->64.233.184.188:5228
  f34
  n[::1]:52784->[::1]:3000
  f38
  n*:8080
  """
let lsofPorts = SocketTracker.shared.parsePorts(from: sampleLsofOutput)
assert(lsofPorts.contains(53086), "Missing port 53086")
assert(lsofPorts.contains(52661), "Missing port 52661")
assert(lsofPorts.contains(52784), "Missing port 52784")
assert(lsofPorts.contains(8080), "Missing port 8080")
assert(lsofPorts.count == 4, "Port count mismatch")

let sampleNettopOutput = """
  time,,interface,state,bytes_in,bytes_out,
  05:25:00.218222,cloudd.593,,,597244100,12247614,
  05:25:00.216907,tcp6 2407:aa80:116:4566:e4a0:dc16:5d52:2a80.56330<->2406:da60:8000:c0::305:97fe.443,en0,Established,47099090,1144612,
  05:25:00.210518,quic4 192.168.0.101:51126<->17.248.224.13:443,en0,,5815,8131,
  05:25:00.210889,quic4 192.168.100.118:60982<->17.248.224.66:443,en0,,8402,9234,
  """
let nettopPorts = SocketTracker.shared.parseNettopPorts(from: sampleNettopOutput)
assert(nettopPorts.contains(56330), "Missing nettop port 56330")
assert(nettopPorts.contains(51126), "Missing nettop port 51126")
assert(nettopPorts.contains(60982), "Missing nettop port 60982")
assert(nettopPorts.count == 3, "Nettop port count mismatch")
print("  ✅ SocketTracker tests passed (both lsof and nettop flows)!")

// Test 4: Throttle Config Serialization
print("• Testing Throttle Config Serialization...")
let config = ThrottleConfig(
  pid: 1234,
  processName: "testProcess",
  isEnabled: true,
  downloadLimitKBps: 500,
  uploadLimitKBps: 200,
  downloadPipeId: 1000,
  uploadPipeId: 1001
)
let data = try JSONEncoder().encode(config)
let decoded = try JSONDecoder().decode(ThrottleConfig.self, from: data)
assert(decoded.pid == 1234)
assert(decoded.processName == "testProcess")
assert(decoded.isEnabled == true)
assert(decoded.downloadLimitKBps == 500)
assert(decoded.uploadLimitKBps == 200)
print("  ✅ ThrottleConfig tests passed!")

// Test 5: PersistentRuleStore CRUD & Matching
print("• Testing PersistentRuleStore CRUD & Matching...")
let store = PersistentRuleStore.shared
let testRule = PersistentRule(
  processName: "cloudd",
  bundleIdentifier: "com.apple.CloudKit.cloudd",
  displayName: "iCloud Service (cloudd)",
  downloadLimitKBps: 500,
  uploadLimitKBps: 100,
  isEnabled: true,
  autoApplyOnLaunch: true
)
store.saveRule(testRule)
guard let retrievedRule = store.rule(forProcessName: "CLOUDD") else {
  fatalError("Failed to retrieve saved rule for cloudd (case-insensitive)")
}
assert(retrievedRule.downloadLimitKBps == 500, "Download limit mismatch")
assert(retrievedRule.uploadLimitKBps == 100, "Upload limit mismatch")
assert(retrievedRule.autoApplyOnLaunch == true, "autoApply mismatch")
store.deleteRule(forProcessName: "cloudd")
assert(store.rule(forProcessName: "cloudd") == nil, "Failed to delete rule")

// Test deleteAllRules
store.saveRule(testRule)
assert(store.rules.count >= 1, "Rule not saved")
store.deleteAllRules()
assert(store.rules.isEmpty, "deleteAllRules failed to empty rules")

// Test disableAllRules
store.saveRule(testRule)
assert(store.rule(forProcessName: "cloudd")?.isEnabled == true, "Rule should be enabled")
store.disableAllRules()
assert(store.rule(forProcessName: "cloudd")?.isEnabled == false, "disableAllRules failed to disable rule")
store.deleteAllRules()
assert(store.rules.isEmpty, "deleteAllRules failed to clean up")

print("  ✅ PersistentRuleStore tests passed!")

// Test 6: Live Process Network Monitor Sampling Check (with -n flag)
print("• Testing live nettop sampling (with -n flag)...")
let startTime = Date()
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
task.arguments = ["-P", "-L", "1", "-n", "-x", "-J", "bytes_in,bytes_out"]
let pipe = Pipe()
task.standardOutput = pipe
try task.run()
let nettopData = pipe.fileHandleForReading.readDataToEndOfFile()
task.waitUntilExit()
let elapsed = Date().timeIntervalSince(startTime)
assert(task.terminationStatus == 0, "nettop exited with non-zero status")
guard let nettopOutput = String(data: nettopData, encoding: .utf8) else {
  fatalError("Failed to decode nettop output")
}
assert(nettopOutput.contains("bytes_in,bytes_out"), "nettop output missing header")
assert(elapsed < 1.0, "nettop with -n took too long: \(elapsed)s")
print("  ✅ Live nettop sampling succeeded in \(String(format: "%.3f", elapsed))s! Output size: \(nettopOutput.count) characters")

// Test 7: Optimistic Local State Updates on NetworkMonitor
print("• Testing optimistic local state updates...")
Task { @MainActor in
  let monitor = NetworkMonitor.shared
  let dummyConfig = ThrottleConfig(pid: 99999, processName: "testproc", isEnabled: true, downloadLimitKBps: 500, uploadLimitKBps: 200)
  monitor.updateThrottleLocally(for: 99999, config: dummyConfig)
  monitor.clearThrottleLocally(for: 99999)
  monitor.clearAllThrottlesLocally()
  assert(monitor.systemTotals.throttledProcessesCount == 0, "Optimistic clear failed")
  print("  ✅ Optimistic local state tests passed!")
}

print("\n🎉 ALL 7 TESTS PASSED SUCCESSFULLY!")
