import Foundation

/// Represents bandwidth speed units and helper formatting methods.
public enum SpeedUnit: String, CaseIterable, Identifiable {
    case b = "B/s"
    case kb = "KB/s"
    case mb = "MB/s"
    case gb = "GB/s"

    public var id: String { rawValue }

    public var multiplierToBytes: Double {
        switch self {
        case .b: return 1.0
        case .kb: return 1024.0
        case .mb: return 1024.0 * 1024.0
        case .gb: return 1024.0 * 1024.0 * 1024.0
        }
    }

    /// Formats raw bytes per second into human-readable formatted string (e.g. "1.45 MB/s")
    public static func format(bytesPerSecond: Double) -> String {
        if bytesPerSecond <= 0 {
            return "0 KB/s"
        } else if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024.0)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / (1024.0 * 1024.0 * 1024.0))
        }
    }

    /// Formats total accumulated bytes (e.g. "45.2 MB")
    public static func formatTotal(bytes: UInt64) -> String {
        let doubleBytes = Double(bytes)
        if doubleBytes < 1024 {
            return "\(bytes) B"
        } else if doubleBytes < 1024 * 1024 {
            return String(format: "%.1f KB", doubleBytes / 1024.0)
        } else if doubleBytes < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB", doubleBytes / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB", doubleBytes / (1024.0 * 1024.0 * 1024.0))
        }
    }
}
