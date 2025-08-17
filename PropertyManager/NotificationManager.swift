import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    func scheduleTaskReminder(for task: MaintenanceTask) {
        guard task.notify, let due = task.dueDate else { return }
        var triggerDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
        if triggerDate < Date() { triggerDate = Date().addingTimeInterval(5) }
        let content = UNMutableNotificationContent()
        content.title = "Task due: \(task.title)"
        content.body = task.details.isEmpty ? "Task is due today." : task.details
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    func cancelTaskReminder(for task: MaintenanceTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
}
