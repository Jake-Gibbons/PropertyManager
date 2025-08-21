import SwiftUI
import SwiftData

// Reusable RoomView extracted to its own file so FloorplanView can reference it.
// This mirrors the behavior previously in FloorplanView: selection, drag, resize, context menu.
// Corners are square (Rectangle) and transient interaction state is kept local to avoid jitter.

@MainActor
struct RoomView: View {
    @Bindable var room: FloorRoom
    var otherRooms: [FloorRoom]
    var isSelected: Bool
    var snapToGrid: Bool
    var gridSize: CGFloat
    var onSelect: () -> Void
    var onEdit: () -> Void
    var onMoveEnded: () -> Void
    var onResizeEnded: () -> Void
    var onDelete: () -> Void
    var canvasBounds: CGRect

    // Local interaction state to avoid writing to the model continuously (reduces jitter).
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging = false
    @State private var initialPosition = CGPoint.zero

    @State private var resizeTranslation: CGSize = .zero
    @State private var isResizing = false
    @State private var initialSize = CGSize.zero

    var body: some View {
        // model-derived sizes
        let baseWidth = CGFloat(room.width)
        let baseHeight = CGFloat(room.height)

        // temporary sizes/positions for interactive feedback
        let displayWidth = max(FloorplanHelpers.minRoomSize.width, baseWidth + resizeTranslation.width)
        let displayHeight = max(FloorplanHelpers.minRoomSize.height, baseHeight + resizeTranslation.height)

        ZStack(alignment: .topLeading) {
            // Square corners: use Rectangle
            Rectangle()
                .fill(Color(hexOptional: room.colorHex))
                .frame(width: displayWidth, height: displayHeight)
                .overlay(
                    VStack(alignment: .leading, spacing: 6) {
                        Text(room.name).font(.headline).foregroundColor(.primary)
                        Spacer()
                    }.padding(8),
                    alignment: .topLeading
                )
                .overlay(selectionOverlay, alignment: .topLeading)
                .contextMenu {
                    Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                }
                .onTapGesture {
                    // select only
                    onSelect()
                }

            if isSelected {
                ResizeHandle()
                    .frame(width: FloorplanHelpers.handleSize, height: FloorplanHelpers.handleSize)
                    .position(x: displayWidth - FloorplanHelpers.handleSize/2, y: displayHeight - FloorplanHelpers.handleSize/2)
                    .gesture(resizeGesture)
            }
        }
        .frame(width: displayWidth, height: displayHeight)
        .offset(x: dragTranslation.width, y: dragTranslation.height)
        .gesture(dragGesture)
        // When the model changes externally, reset local transient state to avoid jumps.
        .onChange(of: room.x) { _ in if !isDragging { dragTranslation = .zero } }
        .onChange(of: room.y) { _ in if !isDragging { dragTranslation = .zero } }
        .onChange(of: room.width) { _ in if !isResizing { resizeTranslation = .zero } }
        .onChange(of: room.height) { _ in if !isResizing { resizeTranslation = .zero } }
    }

    private var selectionOverlay: some View {
        Group {
            if isSelected {
                Rectangle().stroke(Color.accentColor, lineWidth: 2)
            } else {
                EmptyView()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    initialPosition = CGPoint(x: CGFloat(room.x), y: CGFloat(room.y))
                }
                // Show transient translation only; commit in onEnded
                dragTranslation = CGSize(width: value.translation.width, height: value.translation.height)
            }
            .onEnded { value in
                var newX = initialPosition.x + value.translation.width
                var newY = initialPosition.y + value.translation.height
                var proposed = CGRect(x: newX, y: newY, width: CGFloat(room.width), height: CGFloat(room.height))

                // Snap & align to grid/other rooms
                proposed = FloorplanHelpers.snapAndAlign(proposed: proposed, otherRooms: otherRooms, selfID: room.id, gridSize: gridSize, snapToGrid: snapToGrid)

                // Clamp within canvas bounds
                let clamped = FloorplanHelpers.clamp(proposed, in: canvasBounds)

                // commit to model
                room.x = Double(clamped.origin.x)
                room.y = Double(clamped.origin.y)

                // reset transient state
                dragTranslation = .zero
                isDragging = false
                onMoveEnded()
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !isResizing {
                    isResizing = true
                    initialSize = CGSize(width: CGFloat(room.width), height: CGFloat(room.height))
                }
                resizeTranslation = CGSize(width: value.translation.width, height: value.translation.height)
            }
            .onEnded { value in
                var newW = initialSize.width + value.translation.width
                var newH = initialSize.height + value.translation.height
                var proposed = CGRect(x: CGFloat(room.x), y: CGFloat(room.y), width: newW, height: newH)

                proposed = FloorplanHelpers.snapAndAlign(proposed: proposed, otherRooms: otherRooms, selfID: room.id, gridSize: gridSize, snapToGrid: snapToGrid)

                proposed.size.width = max(FloorplanHelpers.minRoomSize.width, proposed.size.width)
                proposed.size.height = max(FloorplanHelpers.minRoomSize.height, proposed.size.height)

                let clamped = FloorplanHelpers.clamp(proposed, in: canvasBounds)

                room.width = Double(clamped.size.width)
                room.height = Double(clamped.size.height)
                room.x = Double(clamped.origin.x)
                room.y = Double(clamped.origin.y)

                resizeTranslation = .zero
                isResizing = false
                onResizeEnded()
            }
    }
}

private struct ResizeHandle: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
            .overlay(Circle().stroke(Color.secondary.opacity(0.6), lineWidth: 0.5))
    }
}
