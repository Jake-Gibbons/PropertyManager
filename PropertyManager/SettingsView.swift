import SwiftUI
import SwiftData

struct IdentifiedURL: Identifiable { let id = UUID(); let url: URL }

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var shareItem: IdentifiedURL?
    @State private var showImporter = false
    @State private var importURL: URL?
    @State private var exportError: String?
    var body: some View {
        NavigationStack {
            List {
                Section("Backup") {
                    Button { do { let url = try BackupManager.exportJSON(from: context); shareItem = IdentifiedURL(url: url) } catch { exportError = error.localizedDescription } } label: { Label("Export JSON", systemImage: "square.and.arrow.up") }
                    Button { showImporter = true } label: { Label("Import JSON", systemImage: "square.and.arrow.down") }
                }
                if let exportError { Text("Error: \(exportError)").foregroundStyle(.red) }
            }.navigationTitle("Settings")
        }
        .sheet(item: $shareItem) { item in ShareSheet(activityItems: [item.url]) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                importURL = urls.first
                if let u = importURL { do { try BackupManager.importJSON(from: u, into: context) } catch { exportError = error.localizedDescription } }
            case .failure(let error): exportError = error.localizedDescription
            }
        }
        .screenBackground()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
