import SwiftUI

enum Theme {
    // Text colors (aliases to match existing code references)
    static let text = Color.primary
    static let textPrimary = Color.primary
    static let subtext = Color.secondary
    static let danger = Color.red

    // Neutral, professional surfaces using system palette so no asset bundle is required
    #if canImport(UIKit)
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemBackground)
    static let accent = Color(.systemBlue)
    static let accentSecondary = Color(.systemIndigo)
    #else
    static let background = Color(.init(white: 0.97))
    static let surface = Color(.init(white: 0.99))
    static let accent = Color.blue
    static let accentSecondary = Color.purple
    #endif

    static let skeleton = Color(white: 0.92)
}

extension Color {
    static let tmBackground = Theme.background
    static let tmSurface = Theme.surface
    static let tmAccent = Theme.accent
}

// Card container used throughout the app for a consistent elevated surface.
// Uses system colors rather than `.ultraThinMaterial` to avoid material resolution issues on older SDKs.
struct ThemedCard<Content: View>: View {
    var cornerRadius: CGFloat = 12
    var content: () -> Content

    init(cornerRadius: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        VStack {
            content()
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.black.opacity(0.03), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

// Small skeleton used during loading
struct SkeletonRowCard: View {
    var lines: Int = 2
    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Theme.skeleton).frame(height: 14)
                ForEach(0..<lines, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(Theme.skeleton).frame(height: 10)
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

// Convenient modifier for app background - use Theme.background and ignore safe area properly.
extension View {
    func screenBackground() -> some View {
        self
            .background(Theme.background.ignoresSafeArea())
    }
}
