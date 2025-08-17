import SwiftUI

enum Theme {
    static let accent = Color(hex: "#6C8EF5")
    static let bg = Color(hex: "#0D1117")
    static let card = Color(hex: "#161B22")
    static let text = Color.white
    static let subtext = Color.white.opacity(0.7)
    static let skeleton = Color.white.opacity(0.08)
    static let outline = Color.white.opacity(0.08)
    static let cornerRadius: CGFloat = 16
    static let shadow = Color.black.opacity(0.35)
}

struct ThemedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.outline))
            .shadow(color: Theme.shadow, radius: 10, x: 0, y: 6)
    }
}

extension View {
    func screenBackground() -> some View {
        self
            .background(Theme.bg.ignoresSafeArea())
            .tint(Theme.accent)
            .foregroundStyle(Theme.text)
    }
    func sectionHeader(_ title: String, systemImage: String? = nil) -> some View {
        modifier(SectionHeader(title: title, symbol: systemImage))
    }
}

private struct SectionHeader: ViewModifier {
    let title: String; let symbol: String?
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.subtext)
            }
            content
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
