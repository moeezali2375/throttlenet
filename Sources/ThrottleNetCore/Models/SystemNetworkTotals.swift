import Foundation

/// Aggregate bandwidth metrics across the entire system.
public struct SystemNetworkTotals: Equatable {
    public var totalDownloadBytesPerSec: Double = 0.0
    public var totalUploadBytesPerSec: Double = 0.0
    public var totalActiveProcesses: Int = 0
    public var throttledProcessesCount: Int = 0
    
    public var totalDownloadHistory: [Double] = []
    public var totalUploadHistory: [Double] = []
    
    public var formattedDownloadSpeed: String {
        SpeedUnit.format(bytesPerSecond: totalDownloadBytesPerSec)
    }
    
    public var formattedUploadSpeed: String {
        SpeedUnit.format(bytesPerSecond: totalUploadBytesPerSec)
    }
    
    public init(
        totalDownloadBytesPerSec: Double = 0.0,
        totalUploadBytesPerSec: Double = 0.0,
        totalActiveProcesses: Int = 0,
        throttledProcessesCount: Int = 0
    ) {
        self.totalDownloadBytesPerSec = totalDownloadBytesPerSec
        self.totalUploadBytesPerSec = totalUploadBytesPerSec
        self.totalActiveProcesses = totalActiveProcesses
        self.throttledProcessesCount = throttledProcessesCount
    }
}
