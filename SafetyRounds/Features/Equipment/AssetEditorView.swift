import SwiftUI
import SwiftData

struct AssetEditorView: View {
    let asset: Asset?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Asset.tag) private var assets: [Asset]

    @State private var siteID: UUID?
    @State private var newSiteName = ""
    @State private var type: EquipmentType = .extinguisher
    @State private var tag = ""
    @State private var location = ""
    @State private var details = ""
    @State private var intervalDays = 30
    @State private var expiries: [Date?] = [nil, nil, nil]
    @State private var notes = ""
    @State private var confirmingDelete = false

    private var canSave: Bool { (siteID != nil || !newSiteName.trimmingCharacters(in: .whitespaces).isEmpty) && !tag.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Site") {
                    if !sites.isEmpty {
                        Picker("Site", selection: $siteID) {
                            ForEach(sites) { Text($0.name).tag(Optional($0.id)) }
                            Text("New site…").tag(UUID?.none)
                        }
                    }
                    if siteID == nil {
                        TextField(sites.isEmpty ? "Site name (e.g. Main Building)" : "New site name", text: $newSiteName)
                    }
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(EquipmentType.allCases) { Label($0.name, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: type) { _, newType in
                        if asset == nil {
                            intervalDays = newType.defaultIntervalDays
                            if tag.isEmpty || tag.hasPrefix(suggestedPrefixBefore) { tag = suggestedTag(for: newType) }
                        }
                    }
                }

                Section("Identity") {
                    TextField("Tag (printed on the label)", text: $tag)
                        .textInputAutocapitalization(.characters)
                    TextField("Location (Kitchen, left of back door)", text: $location)
                    TextField("Details (10 lb ABC, Amerex B456)", text: $details)
                }

                Section("Schedule") {
                    Stepper("Inspect every \(Formatters.days(intervalDays))", value: $intervalDays, in: 1...365, step: intervalDays < 14 ? 1 : 7)
                    Text(type == .eyewash ? "ANSI Z358.1 calls for a weekly activation." : "Most monthly visual checks are every 30 days.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Service and expiry dates") {
                    ForEach(Array(type.expiryLabels.enumerated()), id: \.offset) { index, label in
                        Toggle(label, isOn: Binding(get: { expiries[index] != nil }, set: { on in expiries[index] = on ? (expiries[index] ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)) : nil }))
                        if let date = expiries[index] {
                            DatePicker("Date", selection: Binding(get: { date }, set: { expiries[index] = $0 }), displayedComponents: .date)
                                .padding(.leading, 16)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }

                if let asset {
                    Section {
                        Button(asset.isActive ? "Archive (keeps history, hides from rounds)" : "Restore to active") { asset.isActive.toggle(); dismiss() }
                        Button("Delete equipment and its history", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(asset == nil ? "New Equipment" : "Edit Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold().disabled(!canSave) }
            }
            .onAppear(perform: load)
            .confirmationDialog("Delete \(asset?.title ?? "") and every inspection recorded for it?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteAll() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var suggestedPrefixBefore: String { "" }

    private func suggestedTag(for type: EquipmentType) -> String {
        let existing = assets.filter { $0.type == type }.count
        return String(format: "%@-%02d", type.tagPrefix, existing + 1)
    }

    private func load() {
        if let asset {
            siteID = asset.siteID
            type = asset.type
            tag = asset.tag
            location = asset.location
            details = asset.details
            intervalDays = asset.intervalDays
            expiries = asset.expiries
            notes = asset.notes
        } else {
            siteID = sites.first?.id
            tag = suggestedTag(for: type)
        }
    }

    private func save() {
        let site: Site
        if let siteID, let found = sites.first(where: { $0.id == siteID }) {
            site = found
        } else {
            site = Site(name: newSiteName.trimmingCharacters(in: .whitespaces))
            context.insert(site)
        }
        let target = asset ?? Asset(site: site, type: type, tag: tag)
        target.siteID = site.id
        target.type = type
        target.tag = tag.trimmingCharacters(in: .whitespaces).uppercased()
        target.location = location.trimmingCharacters(in: .whitespaces)
        target.details = details.trimmingCharacters(in: .whitespaces)
        target.intervalDays = intervalDays
        target.expiries = expiries
        target.notes = notes
        if asset == nil { context.insert(target) }
        dismiss()
    }

    private func deleteAll() {
        guard let asset else { return }
        let id = asset.id
        let history = (try? context.fetch(FetchDescriptor<Inspection>(predicate: #Predicate { $0.assetID == id }))) ?? []
        history.forEach(context.delete)
        context.delete(asset)
        dismiss()
    }
}
