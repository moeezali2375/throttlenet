import SwiftUI
import AppKit

/// Renders the ThrottleNet application icon with rounded squircle corners.
public struct AppIconView: View {
    public let size: CGFloat
    
    public init(size: CGFloat = 32) {
        self.size = size
    }
    
    public var body: some View {
        if let icon = AppIconHelper.shared.appIcon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                Image(systemName: "gauge.with.needle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.6, height: size * 0.6)
                    .foregroundColor(.cyan)
            }
            .frame(width: size, height: size)
        }
    }
}
