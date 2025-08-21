import SwiftUI
import SwiftData

@MainActor
struct AddTaskSheet: View {
    var property: Property?

    @Environment(\.modelContext) private var context
    @EnvironmentObject var notifications: NotificationManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    @State private var frequencyString = ""
    @State private var costString = ""
    @State private var status: TaskStatus = .pending
    @State private var category: TaskCategory = .other
    @State private var notify = false

    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Info")) {
                    TextField("Title", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                }

                Section(header: Text("Status")) {
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }

                Section(header: Text("Schedule")) {
                    Toggle("Has due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                        Toggle("Notify on due date (9am)", isOn: $notify)
                    }

                    TextField("Repeat every N days", text: Binding(
                        get: { frequencyString },
                        set: { frequencyString = $0.filter { $0.isNumber } } // keep only digits
                    ))
                    .keyboardType(.numberPad)
                }

                Section(header: Text("Cost")) {
                    TextField("Cost estimate", text: Binding(
                        get: { costString },
                        set: {
                            let filtered = $0.filter { $0.isNumber || $0 == "." || $0 == "," }
                            costString = filtered.replacingOccurrences(of: ",", with: ".")
                        }
                    ))
                    .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(isSaveDisabled)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .interactiveDismissDisabled(false)
            .padding(.top, 4)
        }
    }

    private func saveTask() {
        let freq: Int? = {
            let s = frequencyString.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : Int(s)
        }()

        let cost: Double? = {
            let s = costString.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : Double(s)
        }()

        let newTask = MaintenanceTask(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details,
            dueDate: hasDueDate ? dueDate : nil,
            frequencyDays: freq,
            costEstimate: cost,
            status: status,
            category: category,
            notify: notify,
            property: property
        )

        context.insert(newTask)
        do {
            try context.save()
            if notify, newTask.dueDate != nil {
                notifications.scheduleTaskReminder(for: newTask)
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save task: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

#if DEBUG
import SwiftUI
struct AddTaskSheet_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskSheet(property: nil)
            .environmentObject(NotificationManager())
    }
}
#endif
