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
assert(SpeedUnit.format(bytesPerSecond: 2.25 * 1024 * 1024 * 1024) == "2.25 GB/s", "Failed 2.25 GB/s")
print("  ✅ SpeedUnit tests passed!")

// Test 2: Total Bytes Formatting
print("• Testing Total Bytes Formatting...")
assert(SpeedUnit.formatTotal(bytes: 512) == "512 B")
assert(SpeedUnit.formatTotal(bytes: 1024 * 50) == "50.0 KB")
assert(SpeedUnit.formatTotal(bytes: 1024 * 1024 * 25) == "25.00 MB")
assert(SpeedUnit.formatTotal(bytes: UInt64(1024 * 1024 * 1024 * 3.5)) == "3.50 GB")
print("  ✅ Total Bytes tests passed!")

// Test 3: Socket Tracker Parsing
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
let ports = SocketTracker.shared.parsePorts(from: sampleLsofOutput)
assert(ports.contains(53086), "Missing port 53086")
assert(ports.contains(52661), "Missing port 52661")
assert(ports.contains(52784), "Missing port 52784")
assert(ports.contains(8080), "Missing port 8080")
assert(ports.count == 4, "Port count mismatch")
print("  ✅ SocketTracker tests passed!")

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

// Test 5: Live Process Network Monitor Sampling Check
print("• Testing live nettop sampling...")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
task.arguments = ["-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"]
let pipe = Pipe()
task.standardOutput = pipe
try task.run()
let nettopData = pipe.fileHandleForReading.readDataToEndOfFile()
task.waitUntilExit()
assert(task.terminationStatus == 0, "nettop exited with non-zero status")
guard let nettopOutput = String(data: nettopData, encoding: .utf8) else {
    fatalError("Failed to decode nettop output")
}
assert(nettopOutput.contains("bytes_in,bytes_out"), "nettop output missing header")
print("  ✅ Live nettop sampling succeeded! Output size: \(nettopOutput.count) characters")

print("\n🎉 ALL 5 TESTS PASSED SUCCESSFULLY!")
