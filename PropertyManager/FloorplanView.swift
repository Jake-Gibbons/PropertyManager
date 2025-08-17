import SwiftUI
import SwiftData

struct FloorplanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Property.name) private var properties: [Property]
    @State private var selectedProperty: Property?
    @State private var showingAddRoom = false

    private var roomsForSelected: [FloorRoom] {
        guard let p = selectedProperty else { return [] }
        return p.rooms
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker("Property", selection: $selectedProperty) {
                    if selectedProperty == nil { Text("Select property").tag(nil as Property?) }
                    ForEach(properties) { p in Text(p.name).tag(p as Property?) }
                }.pickerStyle(.menu).padding(.horizontal)

                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6,6]))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .frame(maxWidth: .infinity, minHeight: 420)
                        .padding(.horizontal)

                    if let _ = selectedProperty, roomsForSelected.isEmpty {
                        Text("Add rooms to build a simple floor plan.\nDrag to reposition.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary).padding()
                    }
                    ForEach(roomsForSelected) { room in DraggableRoom(room: room) }
                }
                HStack {
                    Button { showingAddRoom = true } label: { Label("Add Room", systemImage: "plus.circle.fill") }.disabled(selectedProperty == nil)
                    Spacer()
                    Button(role: .destructive) {
                        guard let p = selectedProperty else { return }
                        p.rooms.forEach(context.delete); try? context.save()
                    } label: { Label("Clear", systemImage: "trash") }.disabled(selectedProperty == nil || roomsForSelected.isEmpty)
                }.padding(.horizontal)
            }.navigationTitle("Floorplan")
        }
        .sheet(isPresented: $showingAddRoom) { if let p = selectedProperty { AddRoomSheet(property: p) } }
        .screenBackground()
    }
}

private struct DraggableRoom: View {
    @Environment(\.modelContext) private var context
    @Bindable var room: FloorRoom
    @GestureState private var isPressing: Bool = false
    @State private var drag: CGSize = .zero
    var body: some View {
        let rect = CGRect(x: room.x, y: room.y, width: room.width, height: room.height)
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: room.colorHex).opacity(0.28))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: room.colorHex), lineWidth: 2))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX + drag.width, y: rect.midY + drag.height)
            .overlay {
                Text(room.name).font(.caption).padding(6).background(.thinMaterial, in: Capsule()).offset(y: -rect.height/2 - 12)
            }
            .scaleEffect(isPressing ? 1.03 : 1.0)
            .gesture(
                LongPressGesture(minimumDuration: 0.05).updating($isPressing) { _, s, _ in s = true }
                .simultaneously(with:
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag = $0.translation }
                        .onEnded { room.x += $0.translation.width; room.y += $0.translation.height; drag = .zero; try? context.save() }
                )
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isPressing)
    }
}

private struct AddRoomSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let property: Property
    @State private var name = ""; @State private var width: String = "120"; @State private var height: String = "100"
    var body: some View {
        NavigationStack {
            Form { TextField("Room name", text: $name); TextField("Width (pt)", text: $width).keyboardType(.numberPad); TextField("Height (pt)", text: $height).keyboardType(.numberPad) }
            .navigationTitle("Add Room")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let r = FloorRoom(name: name.isEmpty ? "Room" : name, x: 80, y: 80, width: Double(width) ?? 120, height: Double(height) ?? 100, colorHex: "#89CFF0", property: property)
                        context.insert(r); try? context.save(); dismiss()
                    }
                }
            }
        }
    }
}
