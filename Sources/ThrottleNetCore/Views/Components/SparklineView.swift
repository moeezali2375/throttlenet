import SwiftUI

/// A mini live sparkline chart visualizing bandwidth activity over time.
public struct SparklineView: View {
    public let data: [Double]
    public let lineColor: Color
    public let fillColor: Color
    public let lineWidth: CGFloat
    
    public init(
        data: [Double],
        lineColor: Color = .blue,
        fillColor: Color = .blue.opacity(0.15),
        lineWidth: CGFloat = 1.5
    ) {
        self.data = data
        self.lineColor = lineColor
        self.fillColor = fillColor
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let points = normalizePoints(in: geometry.size)
            
            ZStack {
                // Gradient Fill
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geometry.size.height))
                        for pt in points {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [fillColor, fillColor.opacity(0.0)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Line Path
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
    
    private func normalizePoints(in size: CGSize) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        let maxVal = max(data.max() ?? 1.0, 1024.0) // at least 1 KB scale
        let stepX = size.width / CGFloat(max(data.count - 1, 1))
        
        return data.enumerated().map { index, val in
            let x = CGFloat(index) * stepX
            let normalizedY = 1.0 - (CGFloat(val) / CGFloat(maxVal))
            let y = max(min(normalizedY * (size.height - 4) + 2, size.height), 0)
            return CGPoint(x: x, y: y)
        }
    }
}
