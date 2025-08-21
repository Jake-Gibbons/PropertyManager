import SwiftUI
import SwiftData

@MainActor
struct TaskDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var notifications: NotificationManager
    @Bindable var task: MaintenanceTask
    @Environment(\.dismiss) private var dismiss

    // Safe bindings for optionals / numeric fields
    private var dueDateBinding: Binding<Date> {
        Binding<Date>(
            get: { task.dueDate ?? Date() },
            set: { task.dueDate = $0 }
        )
    }

    private var frequencyStringBinding: Binding<String> {
        Binding<String>(
            get: { task.frequencyDays.map(String.init) ?? "" },
            set: { task.frequencyDays = Int($0) }
        )
    }

    private var costStringBinding: Binding<String> {
        Binding<String>(
            get: { task.costEstimate.map { String($0) } ?? "" },
            set: { task.costEstimate = Double($0) }
        )
    }

    var body: some View {
        Form {
            Section("Status") {
                Picker("Status", selection: $task.status) {
                    ForEach(TaskStatus.allCases) { s in
                        Text(s.rawValue.capitalized).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Info") {
                TextField("Title", text: $task.title)
                TextField("Details", text: $task.details, axis: .vertical)
            }

            Section("Schedule") {
                Toggle("Has due date", isOn: Binding(
                    get: { task.dueDate != nil },
                    set: { has in
                        task.dueDate = has ? (task.dueDate ?? Date()) : nil
                        if !has { notifications.cancelTaskReminder(for: task) }
                    }
                ))
                if task.dueDate != nil {
                    DatePicker("Due date", selection: dueDateBinding, displayedComponents: .date)
                    Toggle("Notify on due date (9am)", isOn: $task.notify)
                        .onChange(of: task.notify) { newValue in
                            if newValue {
                                notifications.scheduleTaskReminder(for: task)
                            } else {
                                notifications.cancelTaskReminder(for: task)
                            }
                        }
                }
                TextField("Repeat every N days", text: frequencyStringBinding)
                    .keyboardType(.numberPad)
            }

            Section("Cost & Category") {
                TextField("Cost estimate", text: costStringBinding)
                    .keyboardType(.decimalPad)
                Picker("Category", selection: $task.category) {
                    ForEach(TaskCategory.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
            }
        }
        .navigationTitle("Task")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .screenBackground()
    }

    private func save() {
        do {
            try context.save()
            if task.notify, task.dueDate != nil {
                notifications.scheduleTaskReminder(for: task)
            }
            dismiss()
        } catch {
            // Replace with user-facing error handling if desired
            print("Failed to save task: \(error)")
        }
    }
}

#if DEBUG
struct TaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Minimal preview; requires a model context to fully work in Xcode previews
        Text("TaskDetailView preview - attach a modelContext to preview in Xcode")
    }
}
#endif
