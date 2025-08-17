import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.35), .clear]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .mask(content)
                .offset(x: phase * 220, y: phase * 180)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
extension View { func shimmer() -> some View { modifier(Shimmer()) } }

struct SkeletonRowCard: View {
    var lines: Int = 2
    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6).fill(Theme.skeleton).frame(height: 18).shimmer()
                ForEach(0..<lines, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(Theme.skeleton).frame(height: 12).shimmer()
                }
            }
        }
    }
}
struct SkeletonList: View {
    var count: Int = 5
    var body: some View {
        VStack(spacing: 12) { ForEach(0..<count, id: \.self) { _ in SkeletonRowCard(lines: Int.random(in: 1...3)) } }
    }
}
