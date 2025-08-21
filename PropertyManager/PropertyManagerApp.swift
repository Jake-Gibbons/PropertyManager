import SwiftUI
import SwiftData

@main
struct PropertyManagerApp: App {
    @StateObject private var notifications = NotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notifications)
                .onAppear {
                    Task {
                        await notifications.requestAuthorization()
                    }
                }
                .modelContainer(for: [
                    Property.self,
                    MaintenanceTask.self,
                    DocumentItem.self,
                    UtilityAccount.self,
                    InventoryItem.self,
                    FloorRoom.self
                ])
        }
    }
}
