import Foundation

/// A persistent bandwidth throttling rule saved by process name or bundle identifier.
public struct PersistentRule: Codable, Identifiable, Equatable {
    public var id: UUID
    public var processName: String
    public var bundleIdentifier: String?
    public var displayName: String
    public var downloadLimitKBps: Double
    public var uploadLimitKBps: Double
    public var isEnabled: Bool
    public var autoApplyOnLaunch: Bool
    public var createdAt: Date
    public var lastAppliedAt: Date?
    
    public init(
        id: UUID = UUID(),
        processName: String,
        bundleIdentifier: String? = nil,
        displayName: String,
        downloadLimitKBps: Double = 500,
        uploadLimitKBps: Double = 0,
        isEnabled: Bool = true,
        autoApplyOnLaunch: Bool = true,
        createdAt: Date = Date(),
        lastAppliedAt: Date? = nil
    ) {
        self.id = id
        self.processName = processName.lowercased()
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.downloadLimitKBps = downloadLimitKBps
        self.uploadLimitKBps = uploadLimitKBps
        self.isEnabled = isEnabled
        self.autoApplyOnLaunch = autoApplyOnLaunch
        self.createdAt = createdAt
        self.lastAppliedAt = lastAppliedAt
    }
}
