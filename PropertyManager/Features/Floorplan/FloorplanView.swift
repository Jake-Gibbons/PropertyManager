import SwiftUI
import SwiftData
import CoreGraphics

@MainActor
struct FloorplanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FloorRoom.name) private var rooms: [FloorRoom]
    @Query(sort: \FloorWall.id) private var walls: [FloorWall]

    // Optional: when showing a floorplan for a specific property, filter by property id.
    var property: Property?

    // selection / editing state
    @State private var selectedRoomID: UUID? = nil
    @State private var isEditingRoom = false

    // drawing state & tools
    @State private var showGrid = true
    @State private var snapToGrid = true
    @State private var isDrawingWalls = false
    @State private var currentDrawingPoints: [CGPoint] = []
    @State private var canvasSize: CGSize = .zero
    @State private var showingDeleteConfirm = false

    // Temporary editing fields for room sheet
    @State private var editName = ""
    @State private var editColorHex = "#9AC0FF"
    @State private var editWidth: CGFloat = FloorplanHelpers.defaultRoomSize.width
    @State private var editHeight: CGFloat = FloorplanHelpers.defaultRoomSize.height

    private func roomBinding(for id: UUID) -> FloorRoom? {
        rooms.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // cache displayed lists to reduce expression complexity
                let displayedRooms = displayRooms()
                let displayedWalls = displayWalls()

                ZStack {
                    Theme.background.ignoresSafeArea()

                    if showGrid {
                        GridBackground(size: geo.size, spacing: FloorplanHelpers.gridSize)
                    }

                    // Rooms and walls canvas
                    ZStack(alignment: .topLeading) {
                        // Draw existing walls first (so rooms render above them)
                        ForEach(displayedWalls, id: \.id) { wall in
                            if !wall.points.isEmpty {
                                WallView(points: wall.points, colorHex: wall.colorHex)
                                    .zIndex(0)
                            }
                        }

                        // Rooms
                        ForEach(displayedRooms, id: \.id) { roomModel in
                            roomContainer(for: roomModel, canvasSize: geo.size, otherRooms: displayedRooms)
                                .zIndex(1)
                        }

                        // If user is drawing walls, overlay a top-level transparent layer to capture taps
                        if isDrawingWalls {
                            // top layer to capture taps for drawing (on top of rooms)
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            // location relative to this ZStack (which is full canvas)
                                            let loc = value.location
                                            handleCanvasTap(at: loc, canvasSize: geo.size, otherRooms: displayedRooms)
                                        }
                                )
                                .zIndex(5)
                        } else {
                            // when not drawing, a behind-the-rooms tap clears selection
                            // this Rectangle is behind rooms so room taps still work
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { clearSelection() }
                                .zIndex(-1)
                        }

                        // live preview of currently drawn polyline (on top)
                        if isDrawingWalls && !currentDrawingPoints.isEmpty {
                            DrawingPreview(points: currentDrawingPoints)
                                .zIndex(6)
                        }
                    }
                    .coordinateSpace(name: "floorplanCanvas")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { new in canvasSize = new }

                    // Floating toolbar: always visible and includes draw-wall toggle & finish/cancel actions
                    floatingToolbar
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                } // ZStack
            } // GeometryReader
            .navigationTitle("Floorplan")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { addRoom() } label: { Image(systemName: "plus.square.on.square") }
                    Button { showGrid.toggle() } label: { Image(systemName: showGrid ? "square.grid.3x3" : "square") }
                    Menu {
                        Toggle(isOn: $snapToGrid) { Text("Snap to grid") }
                        Button(role: .destructive) {
                            if selectedRoomID != nil { showingDeleteConfirm = true }
                        } label: { Label("Delete selected", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $isEditingRoom, onDismiss: { selectedRoomID = nil }) {
                if let selected = selectedRoomID, let room = roomBinding(for: selected) {
                    editSheet(for: room)
                } else {
                    Text("No room selected").padding()
                }
            }
            .confirmationDialog("Delete room?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let sel = selectedRoomID { performDeleteRoom(sel) }
                }
                Button("Cancel", role: .cancel) {}
            }
        } // NavigationStack
    } // body

    // MARK: - Drawing helpers

    private func displayWalls() -> [FloorWall] {
        if let prop = property {
            return walls.filter { $0.property?.id == prop.id }
        } else {
            return walls
        }
    }

    private func handleCanvasTap(at location: CGPoint, canvasSize: CGSize, otherRooms: [FloorRoom]) {
        // location is in canvas coordinate space (top-left origin)
        // If user taps the first point (close within threshold) and there are >=3 points -> close polygon
        let threshold: CGFloat = 12.0

        if currentDrawingPoints.isEmpty {
            currentDrawingPoints.append(location)
            return
        }

        // if tap is near the first point and we have enough points, close
        if let first = currentDrawingPoints.first, distance(first, location) <= threshold, currentDrawingPoints.count >= 3 {
            // create a wall polygon (optionally snap/align the polygon before saving)
            var proposed = currentDrawingPoints
            // optional: snap each point to grid if enabled
            if snapToGrid {
                proposed = proposed.map { CGPoint(x: FloorplanHelpers.snap($0.x, to: FloorplanHelpers.gridSize, enabled: true),
                                                  y: FloorplanHelpers.snap($0.y, to: FloorplanHelpers.gridSize, enabled: true)) }
            }

            // create model and persist
            let wall = FloorWall(points: proposed.map { $0 }, colorHex: "#999999", property: property)
            context.insert(wall)
            do {
                try context.save()
            } catch {
                print("Failed to save wall: \(error)")
            }

            // finish drawing
            currentDrawingPoints.removeAll()
            isDrawingWalls = false
            return
        }

        // otherwise append the point (with snapping if enabled)
        var p = location
        if snapToGrid {
            p.x = FloorplanHelpers.snap(p.x, to: FloorplanHelpers.gridSize, enabled: true)
            p.y = FloorplanHelpers.snap(p.y, to: FloorplanHelpers.gridSize, enabled: true)
        }

        currentDrawingPoints.append(p)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // Finish the current polygon explicitly (e.g., user pressed Finish button)
    private func finishCurrentPolygon() {
        guard currentDrawingPoints.count >= 3 else { return }
        // same logic as closing by tapping first point
        let proposed = currentDrawingPoints
        let wall = FloorWall(points: proposed.map { $0 }, colorHex: "#999999", property: property)
        context.insert(wall)
        do { try context.save() }
        catch { print("Failed to save wall: \(error)") }
        currentDrawingPoints.removeAll()
        isDrawingWalls = false
    }

    private func cancelCurrentPolygon() {
        currentDrawingPoints.removeAll()
        isDrawingWalls = false
    }

    // MARK: - Subviews/helpers to reduce compiler complexity

    @ViewBuilder
    private func roomContainer(for r: FloorRoom, canvasSize: CGSize, otherRooms: [FloorRoom]) -> some View {
        let px = CGFloat(r.x) + CGFloat(r.width) / 2.0
        let py = CGFloat(r.y) + CGFloat(r.height) / 2.0

        RoomView(
            room: r,
            otherRooms: otherRooms,
            isSelected: r.id == selectedRoomID,
            snapToGrid: snapToGrid,
            gridSize: FloorplanHelpers.gridSize,
            onSelect: {
                // only select (do not open sheet)
                selectRoom(r)
            },
            onEdit: {
                // explicit "info" / edit action from UI
                selectedRoomID = r.id
                editName = r.name
                editColorHex = r.colorHex ?? ""
                editWidth = CGFloat(r.width)
                editHeight = CGFloat(r.height)
                isEditingRoom = true
            },
            onMoveEnded: { saveContextIfNeeded() },
            onResizeEnded: { saveContextIfNeeded() },
            onDelete: { performDeleteRoom(r.id) },
            canvasBounds: CGRect(origin: .zero, size: canvasSize)
        )
        .position(x: px, y: py)
    }

    private var floatingToolbar: some View {
        VStack(spacing: 10) {
            Button { addRoom() } label: { Image(systemName: "plus.square.on.square") }
                .buttonStyle(.borderless)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button { showGrid.toggle() } label: { Image(systemName: showGrid ? "square.grid.3x3" : "square") }
                .buttonStyle(.borderless)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                if selectedRoomID != nil {
                    // info action: open sheet for selected room
                    if let sel = selectedRoomID, let room = roomBinding(for: sel) {
                        editName = room.name
                        editColorHex = room.colorHex ?? ""
                        editWidth = CGFloat(room.width)
                        editHeight = CGFloat(room.height)
                    }
                    isEditingRoom = true
                } else {
                    snapToGrid.toggle()
                }
            } label: {
                Image(systemName: selectedRoomID != nil ? "info.circle" : (snapToGrid ? "magnet" : "magnet.slash"))
            }
            .buttonStyle(.borderless)
            .padding(8)
            .background(selectedRoomID != nil ? Color(.systemBackground).opacity(0.95) : (snapToGrid ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground)))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Draw wall toggle + finish/cancel while drawing
            Button(action: {
                isDrawingWalls.toggle()
                if !isDrawingWalls {
                    // leaving draw mode cancels any partial polygon
                    currentDrawingPoints.removeAll()
                }
            }) {
                Image(systemName: isDrawingWalls ? "pencil.and.outline" : "pencil")
            }
            .buttonStyle(.borderless)
            .padding(8)
            .background(isDrawingWalls ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if isDrawingWalls {
                HStack(spacing: 8) {
                    Button { finishCurrentPolygon() } label: { Image(systemName: "checkmark") }
                        .buttonStyle(.borderless)
                        .padding(8)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button { cancelCurrentPolygon() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .padding(8)
                        .background(Color(.systemBackground).opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if selectedRoomID != nil {
                Button(role: .destructive) { showingDeleteConfirm = true } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private func editSheet(for room: FloorRoom) -> some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $editName)
                    #if canImport(UIKit)
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hexOptional: editColorHex) },
                        set: { newColor in
                            if let uiColor = UIColor(newColor) as UIColor? {
                                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                                if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
                                    editColorHex = String(format: "%02X%02X%02X", Int((r*255).rounded()), Int((g*255).rounded()), Int((b*255).rounded()))
                                }
                            }
                        }), supportsOpacity: false)
                    #else
                    ColorPicker("Color", selection: Binding(get: { Color(hexOptional: editColorHex) }, set: { _ in }), supportsOpacity: false)
                    #endif
                }

                Section("Dimensions") {
                    HStack {
                        Text("Width"); Spacer()
                        TextField("Width", value: $editWidth, formatter: NumberFormatter())
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Height"); Spacer()
                        TextField("Height", value: $editHeight, formatter: NumberFormatter())
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button("Save") {
                        applyEditsTo(room)
                        isEditingRoom = false
                    }
                    Button("Cancel", role: .cancel) { isEditingRoom = false }
                }

                // Destructive delete inside the sheet
                Section {
                    Button("Delete Room", role: .destructive) {
                        performDeleteRoom(room.id)
                        isEditingRoom = false
                    }
                }
            }
            .navigationTitle("Room Info")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { isEditingRoom = false } }
            }
            .onAppear {
                editName = room.name
                editColorHex = room.colorHex ?? ""
                editWidth = CGFloat(room.width)
                editHeight = CGFloat(room.height)
            }
        }
    }

    // MARK: - Model helpers (rooms)

    private func displayRooms() -> [FloorRoom] {
        if let prop = property {
            return rooms.filter { $0.property?.id == prop.id }
        } else {
            return rooms
        }
    }

    private func selectRoom(_ room: FloorRoom) {
        selectedRoomID = room.id
        // populate editing state in preparation for quick access from the info button
        editName = room.name
        editColorHex = room.colorHex ?? ""
        editWidth = CGFloat(room.width)
        editHeight = CGFloat(room.height)
        // do not open sheet here
    }

    private func clearSelection() {
        selectedRoomID = nil
    }

    private func addRoom() {
        let new = FloorRoom(id: UUID(),
                            name: "Room \(rooms.count + 1)",
                            x: max(16, Double((canvasSize.width - FloorplanHelpers.defaultRoomSize.width) / 2)),
                            y: max(16, Double((canvasSize.height - FloorplanHelpers.defaultRoomSize.height) / 2)),
                            width: Double(FloorplanHelpers.defaultRoomSize.width),
                            height: Double(FloorplanHelpers.defaultRoomSize.height),
                            colorHex: "9AC0FF",
                            property: property)
        context.insert(new)
        do {
            try context.save()
            selectedRoomID = new.id
            // open the sheet for quick tuning
            editName = new.name
            editColorHex = new.colorHex ?? ""
            editWidth = CGFloat(new.width)
            editHeight = CGFloat(new.height)
            isEditingRoom = true
        } catch {
            print("Failed to save new room: \(error)")
        }
    }

    private func performDeleteRoom(_ id: UUID) {
        guard let room = roomBinding(for: id) else { return }
        context.delete(room)
        do {
            try context.save()
            selectedRoomID = nil
        } catch {
            print("Failed to delete room: \(error)")
        }
    }

    private func applyEditsTo(_ room: FloorRoom) {
        room.name = editName
        room.colorHex = editColorHex
        room.width = Double(max(FloorplanHelpers.minRoomSize.width, editWidth))
        room.height = Double(max(FloorplanHelpers.minRoomSize.height, editHeight))

        // Ensure room stays within canvas bounds (simple clamp)
        let rect = CGRect(x: CGFloat(room.x), y: CGFloat(room.y), width: CGFloat(room.width), height: CGFloat(room.height))
        let clamped = FloorplanHelpers.clamp(rect, in: CGRect(origin: .zero, size: canvasSize))
        room.x = Double(clamped.origin.x)
        room.y = Double(clamped.origin.y)
        room.width = Double(clamped.size.width)
        room.height = Double(clamped.size.height)

        do { try context.save() }
        catch { print("Failed to save edits: \(error)") }
    }

    private func saveContextIfNeeded() {
        do { try context.save() }
        catch { print("Floorplan save error: \(error)") }
    }
}


/// Visual helpers used by FloorplanView

private struct WallView: View {
    var points: [CGPoint]
    var colorHex: String?

    var body: some View {
        GeometryReader { _ in
            Path { path in
                guard !points.isEmpty else { return }
                path.move(to: points[0])
                for p in points.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
            }
            .fill(Color(hexOptional: colorHex).opacity(0.25))
            .overlay(
                Path { path in
                    guard !points.isEmpty else { return }
                    path.move(to: points[0])
                    for p in points.dropFirst() { path.addLine(to: p) }
                    path.closeSubpath()
                }
                .stroke(Color(hexOptional: colorHex), lineWidth: 2)
            )
        }
        .allowsHitTesting(false)
    }
}

private struct DrawingPreview: View {
    var points: [CGPoint]

    var body: some View {
        GeometryReader { _ in
            Path { path in
                guard !points.isEmpty else { return }
                path.move(to: points[0])
                for p in points.dropFirst() { path.addLine(to: p) }
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
            // draw small handles for each point
            ForEach(Array(points.enumerated()), id: \.0) { idx, p in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .position(p)
            }
        }
        .allowsHitTesting(false)
    }
}
