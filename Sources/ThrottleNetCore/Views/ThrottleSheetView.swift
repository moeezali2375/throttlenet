import SwiftUI

/// Popover / Sheet modal for configuring download and upload limits for a process.
public struct ThrottleSheetView: View {
    public let process: ProcessNetworkInfo
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var downloadLimitKBps: Double
    @State private var uploadLimitKBps: Double
    @State private var enableDownloadLimit: Bool
    @State private var enableUploadLimit: Bool
    
    private let downloadPresets: [(label: String, kbps: Double)] = [
        ("100 KB/s", 100),
        ("250 KB/s", 250),
        ("500 KB/s", 500),
        ("1 MB/s", 1024),
        ("2 MB/s", 2048),
        ("5 MB/s", 5120),
        ("10 MB/s", 10240)
    ]
    
    private let uploadPresets: [(label: String, kbps: Double)] = [
        ("50 KB/s", 50),
        ("100 KB/s", 100),
        ("250 KB/s", 250),
        ("500 KB/s", 500),
        ("1 MB/s", 1024),
        ("2 MB/s", 2048),
        ("5 MB/s", 5120)
    ]
    
    public init(process: ProcessNetworkInfo, viewModel: DashboardViewModel) {
        self.process = process
        self.viewModel = viewModel
        
        let existingConfig = process.throttleConfig
        let dlLimit = existingConfig?.downloadLimitKBps ?? 500.0
        let ulLimit = existingConfig?.uploadLimitKBps ?? 250.0
        
        _downloadLimitKBps = State(initialValue: dlLimit > 0 ? dlLimit : 500.0)
        _uploadLimitKBps = State(initialValue: ulLimit > 0 ? ulLimit : 250.0)
        _enableDownloadLimit = State(initialValue: (existingConfig?.downloadLimitKBps ?? 500.0) > 0)
        _enableUploadLimit = State(initialValue: (existingConfig?.uploadLimitKBps ?? 0) > 0)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header: Process info & current rate
            HStack(spacing: 12) {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(process.rawName)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("• PID \(process.pid)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Current Live Rate")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        SpeedBadgeView(direction: .download, bytesPerSec: process.downloadBytesPerSec)
                        SpeedBadgeView(direction: .upload, bytesPerSec: process.uploadBytesPerSec)
                    }
                }
            }
            .padding(.bottom, 6)
            
            Divider()
            
            // Download Throttling Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Download Limit (Inbound)", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    Spacer()
                    
                    Toggle("", isOn: $enableDownloadLimit)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                if enableDownloadLimit {
                    VStack(alignment: .leading, spacing: 8) {
                        // Slider + direct input
                        HStack(spacing: 12) {
                            Slider(value: $downloadLimitKBps, in: 50...20480, step: 50)
                                .accentColor(.cyan)
                            
                            HStack(spacing: 2) {
                                TextField("", value: $downloadLimitKBps, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 65)
                                    .multilineTextAlignment(.trailing)
                                
                                Text("KB/s")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Presets
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(downloadPresets, id: \.kbps) { preset in
                                    Button(action: {
                                        downloadLimitKBps = preset.kbps
                                    }) {
                                        Text(preset.label)
                                            .font(.system(size: 10, weight: downloadLimitKBps == preset.kbps ? .bold : .regular))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(downloadLimitKBps == preset.kbps ? .cyan : .secondary)
                                    .controlSize(.mini)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            // Upload Throttling Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Upload Limit (Outbound)", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Toggle("", isOn: $enableUploadLimit)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                if enableUploadLimit {
                    VStack(alignment: .leading, spacing: 8) {
                        // Slider + direct input
                        HStack(spacing: 12) {
                            Slider(value: $uploadLimitKBps, in: 25...10240, step: 25)
                                .accentColor(.orange)
                            
                            HStack(spacing: 2) {
                                TextField("", value: $uploadLimitKBps, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 65)
                                    .multilineTextAlignment(.trailing)
                                
                                Text("KB/s")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Presets
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(uploadPresets, id: \.kbps) { preset in
                                    Button(action: {
                                        uploadLimitKBps = preset.kbps
                                    }) {
                                        Text(preset.label)
                                            .font(.system(size: 10, weight: uploadLimitKBps == preset.kbps ? .bold : .regular))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(uploadLimitKBps == preset.kbps ? .orange : .secondary)
                                    .controlSize(.mini)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
            
            // Footer actions
            HStack {
                if process.isThrottled {
                    Button(role: .destructive, action: {
                        viewModel.removeThrottle(for: process)
                        viewModel.isShowingThrottleSheet = false
                    }) {
                        Label("Remove Throttle", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button("Cancel") {
                    viewModel.isShowingThrottleSheet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button(action: {
                    let dl = enableDownloadLimit ? downloadLimitKBps : 0
                    let ul = enableUploadLimit ? uploadLimitKBps : 0
                    viewModel.applyThrottle(for: process, downloadLimitKBps: dl, uploadLimitKBps: ul)
                }) {
                    if viewModel.isPerformingAction {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(process.isThrottled ? "Update Limit" : "Apply Throttle")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isPerformingAction || (!enableDownloadLimit && !enableUploadLimit))
            }
        }
        .padding(20)
        .frame(width: 480, height: 420)
    }
}
