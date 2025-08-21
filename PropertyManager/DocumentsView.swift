import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct DocumentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DocumentItem.title) private var documents: [DocumentItem]
    @Query(sort: \Property.name) private var properties: [Property]

    @State private var title = ""
    @State private var kind = "Other"
    @State private var notes = ""
    @State private var selectedProperty: Property?
    @State private var showImporter = false
    @State private var importedURL: URL?
    @State private var photoItem: PhotosPickerItem?

    let kinds = ["Insurance","Warranty","Deed","Mortgage","EPC","Survey","Other"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(documents) { doc in
                    NavigationLink { DocumentDetailView(doc: doc) } label: {
                        VStack(alignment: .leading) {
                            Text(doc.title).font(.headline)
                            Text(doc.kind).font(.caption).foregroundStyle(Theme.subtext)
                        }
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        let d = documents[idx]
                        // remove stored file if present
                        if let rel = d.storedPath, let url = FileHelper.urlFor(rel) {
                            try? FileManager.default.removeItem(at: url)
                        }
                        context.delete(d)
                    }
                    do { try context.save() } catch { print("Failed to save after delete: \(error)") }
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImporter = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showImporter) {
                NavigationStack {
                    Form {
                        TextField("Title", text: $title)
                        Picker("Type", selection: $kind) { ForEach(kinds, id: \.self) { Text($0) } }
                        TextField("Notes", text: $notes, axis: .vertical)
                        Picker("Property", selection: $selectedProperty) {
                            Text("None").tag(nil as Property?)
                            ForEach(properties) { p in Text(p.name).tag(p as Property?) }
                        }
                        Section("Attachment") {
                            Button("Import file (use Files)") {
                                // In-app: present UIDocumentPicker from a UIKit wrapper; here we just toggle state for your implementation.
                                // You likely have a platform-specific document picker implementation; wire it up here.
                            }
                        }
                        Section {
                            Button("Save") {
                                saveImportedDocument()
                            }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .navigationTitle("Add Document")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showImporter = false } }
                    }
                }
            }
        }
        .screenBackground()
    }

    private func saveImportedDocument() {
        var fileName: String? = nil
        var rel: String? = nil
        if let importedURL {
            if let result = try? FileHelper.copyToDocuments(from: importedURL) {
                fileName = result.fileName
                rel = result.relativePath
            }
        }

        let d = DocumentItem(title: title.isEmpty ? "Untitled Document" : title,
                             kind: kind,
                             notes: notes,
                             fileName: fileName,
                             storedPath: rel,
                             property: selectedProperty)
        context.insert(d)
        do {
            try context.save()
            // reset form
            title = ""
            kind = "Other"
            notes = ""
            selectedProperty = nil
            importedURL = nil
            showImporter = false
        } catch {
            print("Failed to save document: \(error)")
        }
    }
}

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var doc: DocumentItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Info") {
                TextField("Title", text: $doc.title)
                TextField("Type", text: $doc.kind)
                TextField("Notes", text: $doc.notes, axis: .vertical)
            }

            if let rel = doc.storedPath, let url = FileHelper.urlFor(rel) {
                Section("Attachment") {
                    HStack {
                        Text(doc.fileName ?? url.lastPathComponent)
                        Spacer()
                        #if canImport(UIKit)
                        Button("Open") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                        #else
                        Button("Open") {}
                        #endif
                    }
                }
            } else {
                Section("Attachment") {
                    Text("No attachment available").foregroundStyle(Theme.subtext)
                }
            }

            Section {
                Button("Delete Document", role: .destructive) {
                    // Remove stored file if present
                    if let rel = doc.storedPath, let url = FileHelper.urlFor(rel) {
                        try? FileManager.default.removeItem(at: url)
                    }
                    context.delete(doc)
                    do {
                        try context.save()
                        dismiss()
                    } catch {
                        print("Failed to delete document: \(error)")
                    }
                }
            }
        }
        .navigationTitle("Document")
        .screenBackground()
    }
}
