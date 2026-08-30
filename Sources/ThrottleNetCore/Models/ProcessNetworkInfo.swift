import Foundation
import AppKit

/// Model representing a process currently using network bandwidth.
public struct ProcessNetworkInfo: Identifiable, Equatable {
    public var id: pid_t { pid }
    public let pid: pid_t
    public let rawName: String
    public var displayName: String
    public var bundleIdentifier: String?
    public var icon: NSImage?
    
    public var downloadBytesPerSec: Double = 0.0
    public var uploadBytesPerSec: Double = 0.0
    public var totalBytesIn: UInt64 = 0
    public var totalBytesOut: UInt64 = 0
    
    public var downloadHistory: [Double] = []
    public var uploadHistory: [Double] = []
    
    public var throttleConfig: ThrottleConfig?
    public var persistentRule: PersistentRule?
    public var isSystemProcess: Bool = false
    public var lastSeen: Date = Date()
    public var activeSocketCount: Int = 0

    public var isThrottled: Bool {
        return throttleConfig?.isEnabled == true
    }
    
    public var hasPersistentRule: Bool {
        return persistentRule?.isEnabled == true
    }
    
    public var formattedDownloadSpeed: String {
        SpeedUnit.format(bytesPerSecond: downloadBytesPerSec)
    }
    
    public var formattedUploadSpeed: String {
        SpeedUnit.format(bytesPerSecond: uploadBytesPerSec)
    }
    
    public var formattedTotalIn: String {
        SpeedUnit.formatTotal(bytes: totalBytesIn)
    }
    
    public var formattedTotalOut: String {
        SpeedUnit.formatTotal(bytes: totalBytesOut)
    }

    public static func == (lhs: ProcessNetworkInfo, rhs: ProcessNetworkInfo) -> Bool {
        return lhs.pid == rhs.pid &&
               lhs.downloadBytesPerSec == rhs.downloadBytesPerSec &&
               lhs.uploadBytesPerSec == rhs.uploadBytesPerSec &&
               lhs.totalBytesIn == rhs.totalBytesIn &&
               lhs.totalBytesOut == rhs.totalBytesOut &&
               lhs.throttleConfig == rhs.throttleConfig &&
               lhs.persistentRule == rhs.persistentRule &&
               lhs.activeSocketCount == rhs.activeSocketCount
    }
}
