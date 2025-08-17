import SwiftUI
import SwiftData

struct ContentView: View {
    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor(Theme.subtext)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
    }
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house") }
            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
            InventoryView()
                .tabItem { Label("Inventory", systemImage: "shippingbox") }
            DocumentsView()
                .tabItem { Label("Documents", systemImage: "doc") }
            UtilitiesView()
                .tabItem { Label("Utilities", systemImage: "bolt") }
            FloorplanView()
                .tabItem { Label("Floorplan", systemImage: "square.grid.3x3") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .screenBackground()
    }
}
