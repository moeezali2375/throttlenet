import SwiftUI

/// A list row item for an individual process.
public struct ProcessRowView: View {
    public let process: ProcessNetworkInfo
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var isHovered: Bool = false
    
    public var body: some View {
        HStack(spacing: 12) {
            // App / Process Icon
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
            } else {
                Image(systemName: "gearshape.2")
                    .frame(width: 28, height: 28)
                    .foregroundColor(.secondary)
            }
            
            // Name & Process details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(process.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    
                    if process.hasPersistentRule {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.purple)
                            .help("Auto-Rule active: Persists across restarts")
                    }
                    
                    if process.isSystemProcess {
                        Text("SYSTEM")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)
                    }
                }
                
                HStack(spacing: 6) {
                    Text("PID \(process.pid)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("Total: ↓\(process.formattedTotalIn) ↑\(process.formattedTotalOut)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 160, alignment: .leading)
            
            Spacer()
            
            // Live Sparkline Chart
            SparklineView(
                data: process.downloadHistory,
                lineColor: process.isThrottled ? .yellow : .cyan,
                fillColor: (process.isThrottled ? Color.yellow : Color.cyan).opacity(0.15)
            )
            .frame(width: 70, height: 22)
            
            // Speed Badges
            HStack(spacing: 6) {
                SpeedBadgeView(direction: .download, bytesPerSec: process.downloadBytesPerSec)
                    .frame(width: 78, alignment: .trailing)
                SpeedBadgeView(direction: .upload, bytesPerSec: process.uploadBytesPerSec)
                    .frame(width: 78, alignment: .trailing)
            }
            
            // Throttling Status & Controls
            HStack(spacing: 8) {
                if process.isThrottled, let config = process.throttleConfig {
                    Button(action: {
                        viewModel.openThrottleSettings(for: process)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 9))
                            
                            let dl = config.downloadLimitKBps > 0 ? "↓\(Int(config.downloadLimitKBps))K" : ""
                            let ul = config.uploadLimitKBps > 0 ? "↑\(Int(config.uploadLimitKBps))K" : ""
                            let label = [dl, ul].filter { !$0.isEmpty }.joined(separator: " ")
                            
                            Text(label.isEmpty ? "Throttled" : label)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Click to modify bandwidth limit")
                    
                    Button(action: {
                        viewModel.removeThrottle(for: process, deletePersistentRule: true)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Remove throttle and auto-rule")
                } else if process.hasPersistentRule, let rule = process.persistentRule {
                    Button(action: {
                        viewModel.openThrottleSettings(for: process)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                            Text("Auto: \(Int(rule.downloadLimitKBps))K")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Auto-Rule configured: Click to edit")
                } else {
                    Button(action: {
                        viewModel.openThrottleSettings(for: process)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 10))
                            Text("Limit")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(process.isThrottled ? Color.yellow.opacity(0.06) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
