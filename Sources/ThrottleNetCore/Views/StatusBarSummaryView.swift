import SwiftUI

/// Header card displaying aggregate network metrics and global status.
public struct StatusBarSummaryView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    public var body: some View {
        let totals = viewModel.monitor.systemTotals
        
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                // Download summary
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL DOWNLOAD")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(totals.formattedDownloadSpeed)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                }
                
                Divider()
                    .frame(height: 24)
                
                // Upload summary
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL UPLOAD")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(totals.formattedUploadSpeed)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // Mini Global Sparkline
                HStack(spacing: 6) {
                    SparklineView(
                        data: totals.totalDownloadHistory,
                        lineColor: .cyan,
                        fillColor: .cyan.opacity(0.2)
                    )
                    .frame(width: 60, height: 26)
                    
                    SparklineView(
                        data: totals.totalUploadHistory,
                        lineColor: .orange,
                        fillColor: .orange.opacity(0.2)
                    )
                    .frame(width: 60, height: 26)
                }
                
                Divider()
                    .frame(height: 24)
                
                // Throttled Badge & Quick Reset
                if totals.throttledProcessesCount > 0 {
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 10))
                            Text("\(totals.throttledProcessesCount) Throttled")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.15))
                        .cornerRadius(6)
                        
                        Button(action: {
                            viewModel.resetAllThrottles()
                        }) {
                            Text("Reset All")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 10))
                        Text("No Limits Active")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            )
        }
    }
}
