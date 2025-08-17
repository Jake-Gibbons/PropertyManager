import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Property.name) private var properties: [Property]
    @Query private var tasks: [MaintenanceTask]
    @State private var isLoading = true

    var upcomingTasks: [MaintenanceTask] {
        tasks.filter { $0.status != .completed }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Properties").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Theme.subtext)
                        if isLoading { SkeletonList(count: 2) } else {
                            if properties.isEmpty {
                                ThemedCard { Text("Add your first property to get started.").foregroundStyle(Theme.subtext) }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(properties) { p in
                                        NavigationLink(value: p) {
                                            ThemedCard {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text(p.name).font(.headline)
                                                        Text(p.address).font(.subheadline).foregroundStyle(Theme.subtext)
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right").foregroundStyle(Theme.subtext)
                                                }
                                            }
                                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        }
                                    }
                                }
                            }
                        }
                        NavigationLink { AddPropertyView() } label: { Label("Add Property", systemImage: "plus.circle.fill") }
                    }

                    Group {
                        Text("Upcoming Tasks").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Theme.subtext)
                        if isLoading { SkeletonList(count: 3) } else if upcomingTasks.isEmpty {
                            ThemedCard { Text("No upcoming tasks.").foregroundStyle(Theme.subtext) }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(upcomingTasks) { t in
                                    ThemedCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(t.title).font(.headline)
                                                Text(t.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "No due date").font(.caption).foregroundStyle(Theme.subtext)
                                            }
                                            Spacer()
                                            Text(t.category.rawValue).font(.caption).padding(.vertical, 6).padding(.horizontal, 10).background(.ultraThinMaterial).clipShape(Capsule())
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Home Hub")
            .navigationDestination(for: Property.self) { property in PropertyDetailView(property: property) }
        }
        .screenBackground()
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeOut(duration: 0.35)) { isLoading = false }
        }
    }
}

struct AddPropertyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var address = ""; @State private var price: String = ""; @State private var date: Date = .now; @State private var notes = ""
    var body: some View {
        Form {
            Section("Basics") { TextField("Name", text: $name); TextField("Address", text: $address, axis: .vertical) }
            Section("Purchase") { DatePicker("Purchase Date", selection: $date, displayedComponents: .date); TextField("Purchase Price (£)", text: $price).keyboardType(.decimalPad) }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
        }
        .navigationTitle("Add Property")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    let p = Property(name: name.isEmpty ? "Untitled" : name, address: address, purchaseDate: date, purchasePrice: Double(price), notes: notes)
                    context.insert(p); try? context.save(); dismiss()
                }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .screenBackground()
    }
}

struct PropertyDetailView: View {
    @Environment(\.modelContext) private var context
    var property: Property

    @Query var tasks: [MaintenanceTask]
    @Query var docs: [DocumentItem]

    init(property: Property) {
        self.property = property

        // Capture the property's ID as OPTIONAL to match the left side (property?.id is UUID?)
        let pidOpt: UUID? = property.id

        let tp = #Predicate<MaintenanceTask> {
            $0.property?.id == pidOpt
        }
        _tasks = Query(filter: tp, sort: \MaintenanceTask.dueDate, order: .forward)

        let dp = #Predicate<DocumentItem> {
            $0.property?.id == pidOpt
        }
        _docs = Query(filter: dp, sort: \DocumentItem.addedAt, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ThemedCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(property.address).font(.subheadline)
                        if let price = property.purchasePrice {
                            Text("Purchase price: £\(price, specifier: "%.2f")")
                                .foregroundStyle(Theme.subtext)
                        }
                        if let date = property.purchaseDate {
                            Text("Purchased: \(date.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundStyle(Theme.subtext)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Tasks")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.subtext)

                    if tasks.isEmpty {
                        ThemedCard { Text("No tasks yet.").foregroundStyle(Theme.subtext) }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(tasks) { t in
                                ThemedCard {
                                    VStack(alignment: .leading) {
                                        Text(t.title).font(.headline)
                                        Text(t.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "No due date")
                                            .font(.caption).foregroundStyle(Theme.subtext)
                                    }
                                }
                            }
                        }
                    }

                    NavigationLink { AddTaskSheet(property: property) } label: {
                        Label("Add Task", systemImage: "plus.circle.fill")
                    }
                }

                if !docs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Documents")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.subtext)

                        VStack(spacing: 10) {
                            ForEach(docs) { d in
                                ThemedCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(d.title).font(.headline)
                                        Text(d.kind).font(.caption).foregroundStyle(Theme.subtext)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(property.name)
        .screenBackground()
    }
}
