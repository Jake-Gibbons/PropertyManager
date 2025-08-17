import SwiftUI
import SwiftData
import PhotosUI

struct DocumentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DocumentItem.addedAt, order: .reverse) private var docs: [DocumentItem]
    @State private var showingAdd = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading { SkeletonList(count: 5) }
                    else if docs.isEmpty { ThemedCard { Text("No documents yet.").foregroundStyle(Theme.subtext) } }
                    else {
                        ForEach(docs) { doc in
                            NavigationLink { DocumentDetailView(doc: doc) } label: {
                                ThemedCard {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(doc.title).font(.headline)
                                        Text("\(doc.kind) • \(doc.addedAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(Theme.subtext)
                                        if !doc.notes.isEmpty { Text(doc.notes).font(.caption).foregroundStyle(Theme.subtext).lineLimit(2) }
                                    }
                                }.transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                    }
                }.padding()
            }
            .navigationTitle("Documents")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") } } }
        }
        .sheet(isPresented: $showingAdd) { AddDocumentSheet() }
        .task { try? await Task.sleep(nanoseconds: 500_000_000); withAnimation(.easeOut(duration: 0.35)) { isLoading = false } }
        .screenBackground()
    }
}

struct AddDocumentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Property.name) private var properties: [Property]
    @State private var title = ""; @State private var kind = "Other"; @State private var notes = ""; @State private var selectedProperty: Property?
    @State private var showImporter = false; @State private var importedURL: URL?; @State private var photoItem: PhotosPickerItem?
    let kinds = ["Insurance","Warranty","Deed","Mortgage","EPC","Survey","Other"]
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Type", selection: $kind) { ForEach(kinds, id: \.self) { Text($0) } }
                TextField("Notes", text: $notes, axis: .vertical)
                Picker("Property", selection: $selectedProperty) { Text("None").tag(nil as Property?); ForEach(properties) { p in Text(p.name).tag(p as Property?) } }
                Section("Attachment") {
                    Button("Import file (PDF/Doc/Image)") { showImporter = true }
                    PhotosPicker("Pick from Photos", selection: $photoItem, matching: .images)
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): importedURL = urls.first
                case .failure: importedURL = nil
                }
            }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task { @MainActor in
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".jpg")
                        try? data.write(to: tmp); importedURL = tmp
                    }
                }
            }
            .navigationTitle("New Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var fileName: String? = nil; var rel: String? = nil
                        if let importedURL, let result = try? FileHelper.copyToDocuments(from: importedURL) { fileName = result.fileName; rel = result.relativePath }
                        let d = DocumentItem(title: title.isEmpty ? "Untitled Document" : title, kind: kind, notes: notes, fileName: fileName, storedPath: rel, property: selectedProperty)
                        context.insert(d); try? context.save(); dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var doc: DocumentItem
    var body: some View {
        Form {
            Section("Info") { TextField("Title", text: $doc.title); TextField("Type", text: $doc.kind); TextField("Notes", text: $doc.notes, axis: .vertical) }
            if let rel = doc.storedPath {
                Section("Attachment") {
                    HStack {
                        Image(systemName: "paperclip"); Text(doc.fileName ?? rel); Spacer()
                        ShareLink(item: FileHelper.urlFor(relativePath: rel)) { Label("Open/Share", systemImage: "square.and.arrow.up") }
                    }
                }
            }
        }
        .navigationTitle("Document")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Save") { try? context.save() } } }
        .screenBackground()
    }
}
