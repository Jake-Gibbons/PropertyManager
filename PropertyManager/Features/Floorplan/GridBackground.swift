import SwiftUI

/// Simple repeating grid background used by FloorplanView.
struct GridBackground: View {
    var size: CGSize
    var spacing: CGFloat
    var lineColor: Color = Color.secondary.opacity(0.06)

    var body: some View {
        GeometryReader { g in
            let w = max(size.width, g.size.width)
            let h = max(size.height, g.size.height)
            Path { path in
                var x: CGFloat = 0
                while x <= w {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= h {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                    y += spacing
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
