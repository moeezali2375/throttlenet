import SwiftUI

public enum SpeedBadgeDirection {
    case download
    case upload
    
    var icon: String {
        switch self {
        case .download: return "arrow.down"
        case .upload: return "arrow.up"
        }
    }
    
    var activeColor: Color {
        switch self {
        case .download: return .cyan
        case .upload: return .orange
        }
    }
}

/// A compact badge displaying download or upload rate.
public struct SpeedBadgeView: View {
    public let direction: SpeedBadgeDirection
    public let bytesPerSec: Double
    
    public init(direction: SpeedBadgeDirection, bytesPerSec: Double) {
        self.direction = direction
        self.bytesPerSec = bytesPerSec
    }
    
    private var isActive: Bool {
        return bytesPerSec > 512
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: direction.icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isActive ? direction.activeColor : .secondary)
            
            Text(SpeedUnit.format(bytesPerSecond: bytesPerSec))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? direction.activeColor.opacity(0.12) : Color.gray.opacity(0.08))
        )
    }
}
