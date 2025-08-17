import SwiftUI
import SwiftData

struct PlannerView: View {
    @Query(sort: \MaintenanceTask.dueDate, order: .forward) private var tasks: [MaintenanceTask]
    var grouped: [(Date, [MaintenanceTask])] {
        let items = tasks.filter { $0.dueDate != nil }
        let groups = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.dueDate!) }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if grouped.isEmpty {
                        ThemedCard { Text("No scheduled tasks. Add due dates to see them here.").foregroundStyle(Theme.subtext) }
                    } else {
                        ForEach(grouped, id: \.0) { date, items in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(date.formatted(date: .complete, time: .omitted)).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Theme.subtext)
                                VStack(spacing: 10) {
                                    ForEach(items) { t in
                                        ThemedCard { VStack(alignment: .leading, spacing: 6) { Text(t.title).font(.headline); if !t.details.isEmpty { Text(t.details).font(.caption).foregroundStyle(Theme.subtext) } } }
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                    }
                                }
                            }
                        }
                    }
                }.padding()
            }.navigationTitle("Planner")
        }.screenBackground()
    }
}
