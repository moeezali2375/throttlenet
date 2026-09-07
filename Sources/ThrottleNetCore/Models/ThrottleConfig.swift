import Foundation

/// Holds bandwidth throttle configuration for a specific process.
public struct ThrottleConfig: Codable, Identifiable, Equatable {
  public var id: pid_t { pid }
  public let pid: pid_t
  public let processName: String
  public var isEnabled: Bool

  /// Maximum allowed download speed in Kilobytes per second (0 = unlimited / no limit).
  public var downloadLimitKBps: Double

  /// Maximum allowed upload speed in Kilobytes per second (0 = unlimited / no limit).
  public var uploadLimitKBps: Double

  /// dummynet pipe ID for download traffic
  public var downloadPipeId: Int?

  /// dummynet pipe ID for upload traffic
  public var uploadPipeId: Int?

  public var lastUpdated: Date

  public init(
    pid: pid_t,
    processName: String,
    isEnabled: Bool = false,
    downloadLimitKBps: Double = 500.0,
    uploadLimitKBps: Double = 250.0,
    downloadPipeId: Int? = nil,
    uploadPipeId: Int? = nil,
    lastUpdated: Date = Date()
  ) {
    self.pid = pid
    self.processName = processName
    self.isEnabled = isEnabled
    self.downloadLimitKBps = downloadLimitKBps
    self.uploadLimitKBps = uploadLimitKBps
    self.downloadPipeId = downloadPipeId
    self.uploadPipeId = uploadPipeId
    self.lastUpdated = lastUpdated
  }
}
