import SwiftUI

extension Color {
    /// Initialize a Color from a hex string.
    /// Accepts: "#RRGGBB", "RRGGBB", "#AARRGGBB", "AARRGGBB" (case-insensitive).
    /// Falls back to `.gray` on parse failure.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }

        // Default components
        var r: Double = 0, g: Double = 0, b: Double = 0, a: Double = 1

        var hexVal: UInt64 = 0
        if Scanner(string: s).scanHexInt64(&hexVal) {
            switch s.count {
            case 6: // RRGGBB
                r = Double((hexVal & 0xFF0000) >> 16) / 255.0
                g = Double((hexVal & 0x00FF00) >> 8) / 255.0
                b = Double(hexVal & 0x0000FF) / 255.0
            case 8: // AARRGGBB
                a = Double((hexVal & 0xFF000000) >> 24) / 255.0
                r = Double((hexVal & 0x00FF0000) >> 16) / 255.0
                g = Double((hexVal & 0x0000FF00) >> 8) / 255.0
                b = Double(hexVal & 0x000000FF) / 255.0
            default:
                // unsupported length; leave defaults (will produce clear/gray)
                break
            }
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Convenience initializer accepting optional hex strings.
    init(hexOptional: String?) {
        if let h = hexOptional, !h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.init(hex: h)
        } else {
            self = .gray
        }
    }
}
