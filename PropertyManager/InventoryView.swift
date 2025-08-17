import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @State private var showingAdd = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        SkeletonList(count: 6)
                    } else if items.isEmpty {
                        ThemedCard { Text("No inventory yet.").foregroundStyle(Theme.subtext) }
                    } else {
                        ForEach(items) { item in
                            NavigationLink { InventoryDetailView(item: item) } label: {
                                ThemedCard {
                                    VStack(alignment: .leading) {
                                        Text(item.name).font(.headline)
                                        Text("\(item.location) • \(item.serialNumber.isEmpty ? "No SN" : item.serialNumber)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.subtext)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddInventorySheet() }
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeOut(duration: 0.35)) { isLoading = false }
        }
        .screenBackground()
    }
}

struct AddInventorySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Property.name) private var properties: [Property]
    
    @State private var name = ""
    @State private var location = ""
    @State private var serial = ""
    @State private var value = ""
    @State private var notes = ""
    @State private var selectedProperty: Property?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                    TextField("Location", text: $location)
                    TextField("Serial number", text: $serial)
                }
                Section("Meta") {
                    TextField("Value (£)", text: $value).keyboardType(.decimalPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                    Picker("Property", selection: $selectedProperty) {
                        Text("None").tag(nil as Property?)
                        ForEach(properties) { p in
                            Text(p.name).tag(p as Property?)
                        }
                    }
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = InventoryItem(
                            name: name.isEmpty ? "Untitled Item" : name,
                            location: location,
                            serialNumber: serial,
                            value: Double(value),
                            notes: notes,
                            property: selectedProperty
                        )
                        context.insert(item)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct InventoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: InventoryItem
    
    // Toggles to control optional dates
    @State private var hasPurchaseDate: Bool = false
    @State private var hasWarrantyExpiry: Bool = false
    
    public init(item: InventoryItem) {
        self._item = Bindable(wrappedValue: item)
        // Initialize toggles based on current data
        _hasPurchaseDate = State(initialValue: item.purchaseDate != nil)
        _hasWarrantyExpiry = State(initialValue: item.warrantyExpiry != nil)
    }
    
    var body: some View {
        Form {
            Section("Info") {
                TextField("Name", text: $item.name)
                TextField("Location", text: $item.location)
                TextField("Serial", text: $item.serialNumber)
                TextField("Notes", text: $item.notes, axis: .vertical)
            }
            
            Section("Value & Dates") {
                // Value
                TextField(
                    "Value (£)",
                    text: Binding(
                        get: { String(item.value ?? 0) },
                        set: { item.value = Double($0) }
                    )
                )
                .keyboardType(.decimalPad)
                
                // Purchase date (optional) — Toggle + DatePicker
                Toggle("Has purchase date", isOn: $hasPurchaseDate)
                    .onChange(of: hasPurchaseDate) { _, newValue in
                        if newValue && item.purchaseDate == nil { item.purchaseDate = Date() }
                        if !newValue { item.purchaseDate = nil }
                    }
                
                if hasPurchaseDate {
                    let purchaseBinding = Binding<Date>(
                        get: { item.purchaseDate ?? Date() },
                        set: { item.purchaseDate = $0 }
                    )
                    DatePicker("Purchase date", selection: purchaseBinding, displayedComponents: .date)
                }
                
                // Warranty expiry (optional) — Toggle + DatePicker
                Toggle("Has warranty expiry", isOn: $hasWarrantyExpiry)
                    .onChange(of: hasWarrantyExpiry) { _, newValue in
                        if newValue && item.warrantyExpiry == nil { item.warrantyExpiry = Date() }
                        if !newValue { item.warrantyExpiry = nil }
                    }
                
                if hasWarrantyExpiry {
                    let warrantyBinding = Binding<Date>(
                        get: { item.warrantyExpiry ?? Date() },
                        set: { item.warrantyExpiry = $0 }
                    )
                    DatePicker("Warranty expiry", selection: warrantyBinding, displayedComponents: .date)
                }
            }
        }
        .navigationTitle("Item")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { try? context.save() }
            }
        }
        .screenBackground()
    }
}
