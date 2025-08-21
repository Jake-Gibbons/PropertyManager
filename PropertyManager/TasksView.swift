import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var notifications: NotificationManager
    @State private var search = ""
    @State private var showingAdd = false
    @State private var isLoading = true
    @Query(sort: \MaintenanceTask.dueDate, order: .forward) private var tasks: [MaintenanceTask]

    private var filtered: [MaintenanceTask] {
        if search.isEmpty { return tasks }
        return tasks.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.details.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading { SkeletonList(count: 6) }
                    else if filtered.isEmpty {
                        ThemedCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("No tasks found.").foregroundStyle(Theme.subtext)
                                Text("Tap + to create a new task").font(.caption).foregroundStyle(Theme.subtext.opacity(0.8))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(filtered) { task in
                            NavigationLink {
                                TaskDetailView(task: task)
                            } label: {
                                TaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    withAnimation(.easeOut(duration: 0.35)) { isLoading = false }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddTaskSheet(property: nil)
                    .environmentObject(notifications)
            }
        }
        .screenBackground()
    }
}

private struct TaskRow: View {
    var task: MaintenanceTask

    var body: some View {
        ThemedCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title).font(.headline)
                    if !task.details.isEmpty {
                        Text(task.details).font(.caption).foregroundStyle(Theme.subtext).lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(task.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                        .font(.caption)
                        .foregroundStyle(Theme.subtext)
                    Text(task.category.rawValue).font(.caption2).foregroundStyle(Theme.subtext)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
