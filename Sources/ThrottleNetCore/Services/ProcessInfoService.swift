import Foundation
import AppKit

/// Service that resolves process metadata (display names, bundle identifiers, icons).
public final class ProcessInfoService {
    public static let shared = ProcessInfoService()
    
    private var iconCache: [pid_t: NSImage] = [:]
    private var nameCache: [pid_t: (displayName: String, bundleId: String?)] = [:]
    private let queue = DispatchQueue(label: "com.throttlenet.processinfo", qos: .utility)
    
    private init() {}
    
    /// Resolves metadata for a PID.
    public func resolveInfo(for pid: pid_t, rawName: String) -> (displayName: String, bundleId: String?, icon: NSImage?, isSystem: Bool) {
        if let cachedName = nameCache[pid], let cachedIcon = iconCache[pid] {
            let isSystem = isSystemDaemon(name: rawName, bundleId: cachedName.bundleId)
            return (cachedName.displayName, cachedName.bundleId, cachedIcon, isSystem)
        }
        
        var displayName = cleanProcessName(rawName)
        var bundleId: String? = nil
        var icon: NSImage? = nil
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            if let localizedName = app.localizedName, !localizedName.isEmpty {
                displayName = localizedName
            }
            bundleId = app.bundleIdentifier
            icon = app.icon
        }
        
        if icon == nil {
            icon = defaultIcon(for: rawName)
        }
        
        let isSystem = isSystemDaemon(name: rawName, bundleId: bundleId)
        
        nameCache[pid] = (displayName, bundleId)
        if let icon = icon {
            iconCache[pid] = icon
        }
        
        return (displayName, bundleId, icon, isSystem)
    }
    
    private func cleanProcessName(_ raw: String) -> String {
        // Handle common daemon names to human-readable versions
        switch raw.lowercased() {
        case "cloudd": return "iCloud Service (cloudd)"
        case "nsurlsessiond": return "macOS Background Downloads (nsurlsessiond)"
        case "mdnsresponder": return "Bonjour / DNS (mDNSResponder)"
        case "apsd": return "Apple Push Notification (apsd)"
        case "rapportd": return "AirPlay / Continuity (rapportd)"
        case "identityservicesd", "identityservice": return "Apple ID & Messages (identityservicesd)"
        case "sharingd": return "AirDrop & Sharing (sharingd)"
        case "bird": return "iCloud Drive Document Sync (bird)"
        case "wifivelocityd": return "Wi-Fi Diagnostics (wifivelocityd)"
        case "spotify helper": return "Spotify Audio Stream"
        case "google chrome helper": return "Google Chrome Tab / Worker"
        case "dropbox": return "Dropbox"
        case "onedrive": return "Microsoft OneDrive"
        default:
            return raw
        }
    }
    
    private func isSystemDaemon(name: String, bundleId: String?) -> Bool {
        if let bundleId = bundleId, bundleId.starts(with: "com.apple.") {
            return true
        }
        let systemDaemons: Set<String> = [
            "cloudd", "nsurlsessiond", "mdnsresponder", "apsd", "rapportd",
            "identityservice", "identityservicesd", "sharingd", "bird",
            "airportd", "wifip2pd", "wifivelocityd", "wifianalyticsd", "replicatord"
        ]
        return systemDaemons.contains(name.lowercased())
    }
    
    private func defaultIcon(for name: String) -> NSImage {
        let lower = name.lowercased()
        if lower.contains("cloud") || lower.contains("bird") {
            return NSImage(systemSymbolName: "icloud.fill", accessibilityDescription: "Cloud") ?? defaultGenericIcon()
        } else if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") || lower.contains("browser") {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: "Browser") ?? defaultGenericIcon()
        } else if lower.contains("spotify") || lower.contains("music") {
            return NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music") ?? defaultGenericIcon()
        } else if lower.contains("chat") || lower.contains("whatsapp") || lower.contains("telegram") || lower.contains("slack") {
            return NSImage(systemSymbolName: "message.fill", accessibilityDescription: "Chat") ?? defaultGenericIcon()
        } else if lower.contains("node") || lower.contains("python") || lower.contains("antigravity") || lower.contains("code") {
            return NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: "Code") ?? defaultGenericIcon()
        } else {
            return defaultGenericIcon()
        }
    }
    
    private func defaultGenericIcon() -> NSImage {
        return NSImage(systemSymbolName: "gearshape.2.fill", accessibilityDescription: "Process") ??
               NSWorkspace.shared.icon(for: .application)
    }
    
    public func clearCache(for pid: pid_t) {
        iconCache.removeValue(forKey: pid)
        nameCache.removeValue(forKey: pid)
    }
}
