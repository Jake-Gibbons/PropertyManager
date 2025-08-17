import SwiftUI
import SwiftData

struct UtilitiesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UtilityAccount.provider) private var utils: [UtilityAccount]
    @State private var showingAdd = false
    @State private var isLoading = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading { SkeletonList(count: 5) }
                    else if utils.isEmpty { ThemedCard { Text("No utilities yet.").foregroundStyle(Theme.subtext) } }
                    else {
                        ForEach(utils) { u in
                            ThemedCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(u.provider).font(.headline)
                                    Text("\(u.type) • \(u.accountNumber)").font(.caption).foregroundStyle(Theme.subtext)
                                    if !u.tariff.isEmpty { Text("Tariff: \(u.tariff)").font(.caption).foregroundStyle(Theme.subtext) }
                                    if !u.notes.isEmpty { Text(u.notes).font(.caption).foregroundStyle(Theme.subtext) }
                                }
                            }.transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                }.padding()
            }
            .navigationTitle("Utilities")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") } } }
        }
        .sheet(isPresented: $showingAdd) { AddUtilitySheet() }
        .task { try? await Task.sleep(nanoseconds: 500_000_000); withAnimation(.easeOut(duration: 0.35)) { isLoading = false } }
        .screenBackground()
    }
}

struct AddUtilitySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Property.name) private var properties: [Property]
    @State private var provider = ""; @State private var accountNumber = ""; @State private var type = "Electricity"; @State private var tariff = ""; @State private var notes = ""; @State private var selectedProperty: Property?
    private let types = ["Gas","Electricity","Water","Broadband","Council Tax","Other"]
    var body: some View {
        NavigationStack {
            Form {
                TextField("Provider", text: $provider)
                TextField("Account number", text: $accountNumber)
                Picker("Type", selection: $type) { ForEach(types, id: \.self) { Text($0) } }
                TextField("Tariff", text: $tariff)
                TextField("Notes", text: $notes, axis: .vertical)
                Picker("Property", selection: $selectedProperty) { Text("None").tag(nil as Property?); ForEach(properties) { p in Text(p.name).tag(p as Property?) } }
            }
            .navigationTitle("New Utility")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let u = UtilityAccount(provider: provider.isEmpty ? "Untitled" : provider, accountNumber: accountNumber, type: type, tariff: tariff, notes: notes, property: selectedProperty)
                        context.insert(u); try? context.save(); dismiss()
                    }.disabled(provider.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
