import SwiftUI

enum FloorplanHelpers {
    static let defaultRoomSize = CGSize(width: 120, height: 90)
    static let minRoomSize = CGSize(width: 40, height: 32)
    static let handleSize: CGFloat = 18
    static let gridSize: CGFloat = 16

    /// How close (points) an edge needs to be to snap to another room edge/center
    static let snapThreshold: CGFloat = 10

    static func snap(_ value: CGFloat, to grid: CGFloat, enabled: Bool) -> CGFloat {
        guard enabled, grid > 0 else { return value }
        return (value / grid).rounded() * grid
    }

    static func clamp(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        var r = rect
        if r.minX < bounds.minX { r.origin.x = bounds.minX }
        if r.minY < bounds.minY { r.origin.y = bounds.minY }
        if r.maxX > bounds.maxX { r.size.width = bounds.maxX - r.minX }
        if r.maxY > bounds.maxY { r.size.height = bounds.maxY - r.minY }
        r.size.width = max(r.size.width, minRoomSize.width)
        r.size.height = max(r.size.height, minRoomSize.height)
        return r
    }

    /// Snap a proposed rect to the grid (if enabled) and align to nearby room edges/centers.
    /// - Parameters:
    ///   - proposed: the proposed rectangle in canvas coordinates
    ///   - otherRooms: other room models on the canvas (their rects will be checked)
    ///   - selfID: the id of the moving/resizing room (so we ignore it)
    ///   - gridSize: grid spacing for grid snap
    ///   - snapToGrid: whether to snap to grid
    /// - Returns: adjusted rect after snapping and alignment
    static func snapAndAlign(proposed: CGRect, otherRooms: [FloorRoom], selfID: UUID?, gridSize: CGFloat, snapToGrid: Bool) -> CGRect {
        var rect = proposed

        // 1) grid snap
        if snapToGrid && gridSize > 0 {
            rect.origin.x = snap(rect.origin.x, to: gridSize, enabled: true)
            rect.origin.y = snap(rect.origin.y, to: gridSize, enabled: true)
            rect.size.width = max(minRoomSize.width, snap(rect.size.width, to: gridSize, enabled: true))
            rect.size.height = max(minRoomSize.height, snap(rect.size.height, to: gridSize, enabled: true))
        }

        // 2) alignment to other rooms: edges and centers
        // Check left, right, top, bottom and center X/Y against other rooms
        let threshold = snapThreshold

        // collect other rects (in CGFloat)
        let others = otherRooms.compactMap { r -> CGRect? in
            guard r.id != selfID else { return nil }
            return CGRect(x: CGFloat(r.x), y: CGFloat(r.y), width: CGFloat(r.width), height: CGFloat(r.height))
        }

        // Candidate adjustments (we try to align edges in order: left/right/top/bottom, then centers)
        for other in others {
            // horizontal align: left to left
            if abs(rect.minX - other.minX) <= threshold {
                rect.origin.x = other.minX
            }
            // left to other's right (snap to right edge)
            if abs(rect.minX - other.maxX) <= threshold {
                rect.origin.x = other.maxX
            }
            // right to other's left
            if abs(rect.maxX - other.minX) <= threshold {
                rect.origin.x = other.minX - rect.width
            }
            // right to other's right
            if abs(rect.maxX - other.maxX) <= threshold {
                rect.origin.x = other.maxX - rect.width
            }
            // center X to center X
            let rectCenterX = rect.midX
            let otherCenterX = other.midX
            if abs(rectCenterX - otherCenterX) <= threshold {
                rect.origin.x = otherCenterX - rect.width / 2.0
            }

            // vertical align: top to top
            if abs(rect.minY - other.minY) <= threshold {
                rect.origin.y = other.minY
            }
            // top to other's bottom
            if abs(rect.minY - other.maxY) <= threshold {
                rect.origin.y = other.maxY
            }
            // bottom to other's top
            if abs(rect.maxY - other.minY) <= threshold {
                rect.origin.y = other.minY - rect.height
            }
            // bottom to other's bottom
            if abs(rect.maxY - other.maxY) <= threshold {
                rect.origin.y = other.maxY - rect.height
            }
            // center Y to center Y
            let rectCenterY = rect.midY
            let otherCenterY = other.midY
            if abs(rectCenterY - otherCenterY) <= threshold {
                rect.origin.y = otherCenterY - rect.height / 2.0
            }
        }

        return rect
    }
}
