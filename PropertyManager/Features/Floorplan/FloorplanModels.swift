import Foundation
import SwiftUI
import SwiftData
import CoreGraphics

// Simple SwiftData model to store drawn walls (polygons).
// Points are stored as JSON-encoded array of simple codable points in pointsData.
@Model
final class FloorWall: Identifiable {
    @Attribute(.unique) var id: UUID
    var pointsData: Data?
    var colorHex: String?
    @Relationship var property: Property?

    init(id: UUID = UUID(), points: [CGPoint], colorHex: String? = "#999999", property: Property? = nil) {
        self.id = id
        self.colorHex = colorHex
        self.property = property
        self.points = points
    }

    private struct CodablePoint: Codable {
        var x: Double
        var y: Double
    }

    var points: [CGPoint] {
        get {
            guard let d = pointsData else { return [] }
            do {
                let decoded = try JSONDecoder().decode([CodablePoint].self, from: d)
                return decoded.map { CGPoint(x: $0.x, y: $0.y) }
            } catch {
                print("FloorWall decode error: \(error)")
                return []
            }
        }
        set {
            let encoded = newValue.map { CodablePoint(x: Double($0.x), y: Double($0.y)) }
            do {
                pointsData = try JSONEncoder().encode(encoded)
            } catch {
                print("FloorWall encode error: \(error)")
                pointsData = nil
            }
        }
    }
}
