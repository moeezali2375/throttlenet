import AppKit
import Foundation

/// Helper to load and cache the ThrottleNet app icon across bundle, development, and runtime modes.
public final class AppIconHelper {
    public static let shared = AppIconHelper()

    public private(set) lazy var appIcon: NSImage? = {
        // 1. Check if applicationIconImage is already valid
        if let current = NSApplication.shared.applicationIconImage,
            current.size.width > 0 && current.size.height > 0
        {
            return current
        }

        // 2. Check Bundle.main image or resource URLs
        if let img = NSImage(named: "AppIcon") {
            return img
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "png")
        {
            if let img = NSImage(contentsOf: url) {
                return img
            }
        }

        // 3. Fallback search relative to working directory
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let candidates = [
            "Resources/AppIcon.icns",
            "Resources/AppIcon.png",
            "../Resources/AppIcon.icns",
            "../Resources/AppIcon.png",
            "../../Resources/AppIcon.icns",
            "../../Resources/AppIcon.png",
        ]

        for rel in candidates {
            let fullPath = (currentDir as NSString).appendingPathComponent(rel)
            if fileManager.fileExists(atPath: fullPath), let img = NSImage(contentsOfFile: fullPath)
            {
                return img
            }
        }

        // 4. Fallback search relative to executable location
        if let execURL = Bundle.main.executableURL {
            var searchURL = execURL.deletingLastPathComponent()
            for _ in 0..<5 {
                let candidate1 = searchURL.appendingPathComponent("Resources/AppIcon.icns")
                let candidate2 = searchURL.appendingPathComponent("Resources/AppIcon.png")
                if fileManager.fileExists(atPath: candidate1.path),
                    let img = NSImage(contentsOf: candidate1)
                {
                    return img
                }
                if fileManager.fileExists(atPath: candidate2.path),
                    let img = NSImage(contentsOf: candidate2)
                {
                    return img
                }
                searchURL = searchURL.deletingLastPathComponent()
            }
        }

        return nil
    }()

    private init() {}
}
