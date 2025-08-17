import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var notifications: NotificationManager
    @State private var search = ""
    @State private var showingAdd = false
    @State private var isLoading = true
    @Query(sort: \MaintenanceTask.dueDate, order: .forward) private var tasks: [MaintenanceTask]

    var filtered: [MaintenanceTask] {
        if search.isEmpty { return tasks }
        return tasks.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.details.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading { SkeletonList(count: 6) }
                    else if filtered.isEmpty {
                        ThemedCard { Text("No tasks found.").foregroundStyle(Theme.subtext) }
                    } else {
                        ForEach(filtered) { task in
                            NavigationLink { TaskDetailView(task: task) } label: {
                                ThemedCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(task.title).font(.headline)
                                            if !task.details.isEmpty { Text(task.details).font(.caption).foregroundStyle(Theme.subtext).lineLimit(1) }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 6) {
                                            Text(task.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "No date").font(.caption).foregroundStyle(Theme.subtext)
                                            Text(task.category.rawValue).font(.caption2).foregroundStyle(Theme.subtext)
                                        }
                                    }
                                }.transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                    }
                }.padding()
            }
            .navigationTitle("Tasks")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") } } }
            .searchable(text: $search)
        }
        .sheet(isPresented: $showingAdd) { AddTaskSheet(property: nil) }
        .task { try? await Task.sleep(nanoseconds: 500_000_000); withAnimation(.easeOut(duration: 0.35)) { isLoading = false } }
        .screenBackground()
    }
}

struct AddTaskSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notifications: NotificationManager
    @Query(sort: \Property.name) private var properties: [Property]
    var property: Property?
    @State private var title = ""; @State private var details = ""
    @State private var dueDate: Date = .now; @State private var hasDate = true
    @State private var frequencyDays: String = ""; @State private var costEstimate: String = ""
    @State private var category: TaskCategory = .other; @State private var notify: Bool = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") { TextField("Title", text: $title); TextField("Details", text: $details, axis: .vertical) }
                Section("When") {
                    Toggle("Set due date", isOn: $hasDate)
                    if hasDate { DatePicker("Due date", selection: $dueDate, displayedComponents: .date); Toggle("Notify on due date (9am)", isOn: $notify) }
                    TextField("Repeat every N days (optional)", text: $frequencyDays).keyboardType(.numberPad)
                }
                Section("Meta") {
                    Picker("Category", selection: $category) { ForEach(TaskCategory.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("Cost estimate (£)", text: $costEstimate).keyboardType(.decimalPad)
                    Picker("Property", selection: .constant(property)) {
                        if let property { Text(property.name).tag(property as Property?) }
                        else {
                            Text("Optional").tag(nil as Property?)
                            ForEach(properties) { p in Text(p.name).tag(p as Property?) }
                        }
                    }.disabled(property != nil)
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let task = MaintenanceTask(title: title.isEmpty ? "Untitled Task" : title, details: details, dueDate: hasDate ? dueDate : nil, frequencyDays: Int(frequencyDays), costEstimate: Double(costEstimate), status: .pending, category: category, notify: notify, property: property)
                        context.insert(task); try? context.save()
                        if notify, hasDate { notifications.scheduleTaskReminder(for: task) }
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct TaskDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var notifications: NotificationManager
    @Bindable var task: MaintenanceTask
    var body: some View {
        Form {
            Section("Status") { Picker("Status", selection: $task.status) { ForEach(TaskStatus.allCases) { Text($0.rawValue.capitalized).tag($0) } } }
            Section("Info") { TextField("Title", text: $task.title); TextField("Details", text: $task.details, axis: .vertical) }
            Section("Schedule") {
                Toggle("Has due date", isOn: Binding(
                    get: { task.dueDate != nil },
                    set: { has in task.dueDate = has ? (task.dueDate ?? .now) : nil; if !has { notifications.cancelTaskReminder(for: task) } }
                ))
                if task.dueDate != nil {
                    DatePicker("Due date", selection: Binding($task.dueDate)!, displayedComponents: .date)
                    Toggle("Notify on due date (9am)", isOn: $task.notify).onChange(of: task.notify) { _, newValue in
                        if newValue { notifications.scheduleTaskReminder(for: task) } else { notifications.cancelTaskReminder(for: task) }
                    }
                }
                TextField("Repeat every N days", text: Binding(get: { String(task.frequencyDays ?? 0) }, set: { task.frequencyDays = Int($0) })).keyboardType(.numberPad)
            }
            Section("Cost & Category") {
                TextField("Cost estimate (£)", text: Binding(get: { String(task.costEstimate ?? 0) }, set: { task.costEstimate = Double($0) })).keyboardType(.decimalPad)
                Picker("Category", selection: $task.category) { ForEach(TaskCategory.allCases) { Text($0.rawValue).tag($0) } }
            }
        }
        .navigationTitle("Task")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Save") { try? context.save(); if task.notify, task.dueDate != nil { notifications.scheduleTaskReminder(for: task) } } } }
        .screenBackground()
    }
}
