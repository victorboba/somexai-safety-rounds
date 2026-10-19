import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(EntitlementStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query private var assets: [Asset]
    @Query private var inspections: [Inspection]

    @AppStorage("inspector.name") private var inspectorName = ""
    @AppStorage(DueReminders.enabledKey) private var remindersEnabled = false
    @AppStorage(DueReminders.hourKey) private var reminderHour = 9
    @State private var confirmingDeleteAll = false
    @State private var editingSite: Site?
    @State private var newSiteName = ""
    #if DEBUG
    @State private var sampleDataImported = false
    @AppStorage(DebugFlags.unlockKey) private var debugUnlock = false
    @AppStorage("onboarding.completed") private var onboardingCompleted = true
    #endif

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Inspector") {
                    TextField("Default inspector name", text: $inspectorName)
                }

                Section("Reminders") {
                    Toggle("Notify me on due dates", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { reschedule() }
                    if remindersEnabled {
                        Picker("At", selection: $reminderHour) {
                            ForEach([7, 8, 9, 10, 12, 15, 17], id: \.self) { h in Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.formatted(date: .omitted, time: .shortened)).tag(h) }
                        }
                        .onChange(of: reminderHour) { reschedule() }
                    }
                }

                Section("Sites") {
                    ForEach(sites) { site in
                        Button { editingSite = site } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(site.name).foregroundStyle(.primary)
                                    if !site.address.isEmpty { Text(site.address).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Text("\(assets.filter { $0.siteID == site.id && $0.isActive }.count)").foregroundStyle(.secondary)
                            }
                        }
                    }
                    HStack {
                        TextField("New site name", text: $newSiteName)
                        Button("Add") {
                            context.insert(Site(name: newSiteName.trimmingCharacters(in: .whitespaces)))
                            newSiteName = ""
                        }
                        .disabled(newSiteName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Your plan") {
                    LabeledContent("Status", value: planDescription)
                    if store.isEntitled && !store.isLifetime {
                        Button("Manage Subscription") { openURL(URL(string: "https://apps.apple.com/account/subscriptions")!) }
                    }
                    Button("Restore Purchases") { Task { await store.restore() } }
                    if let error = store.lastError { Text(error).font(.footnote).foregroundStyle(.red) }
                }

                Section("Your data") {
                    Text("Everything you record stays on this device\(AppConfig.iCloudSyncEnabled ? " and in your private iCloud" : ""). Nothing is sent to us.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Delete All Data", role: .destructive) { confirmingDeleteAll = true }
                }

                Section("About") {
                    Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary)
                    if !AppConfig.appStoreID.isEmpty {
                        Button("Rate \(AppConfig.appName)") { openURL(URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review")!) }
                    }
                    Button("Contact Support") {
                        let subject = "\(AppConfig.appName) \(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        openURL(URL(string: "mailto:\(AppConfig.supportEmail)?subject=\(subject)")!)
                    }
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                    Link("Terms of Use", destination: AppConfig.termsURL)
                    LabeledContent("Version", value: version)
                }

                #if DEBUG
                Section("Debug (not in release builds)") {
                    Toggle("Unlock without purchase", isOn: $debugUnlock)
                        .onChange(of: debugUnlock) { Task { await store.refreshEntitlements() } }
                    Button("Show onboarding again") { onboardingCompleted = false; dismiss() }
                    Button(sampleDataImported ? "Imported ✓" : "Insert sample data") {
                        SampleData.insert(into: context)
                        sampleDataImported = true
                        Task { try? await Task.sleep(for: .seconds(2)); sampleDataImported = false }
                    }
                    .disabled(sampleDataImported)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editingSite) { site in SiteEditorView(site: site) }
            .confirmationDialog("Delete every site, piece of equipment and inspection on this device?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    try? context.delete(model: Inspection.self)
                    try? context.delete(model: Asset.self)
                    try? context.delete(model: Site.self)
                    DueReminders.cancelAll()
                    WidgetSync.update(assets: [], inspections: [])
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone. Export a report first if you want a copy.") }
        }
    }

    private func reschedule() {
        let a = assets, i = inspections
        Task { await DueReminders.reschedule(assets: a, inspections: i) }
    }

    private var planDescription: String {
        guard store.isEntitled else { return "Not active" }
        if store.isLifetime { return "Lifetime" }
        if let expiry = store.expiresAt { return "Annual, renews \(expiry.formatted(date: .abbreviated, time: .omitted))" }
        return "Active"
    }
}

struct SiteEditorView: View {
    let site: Site
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var assets: [Asset]
    @State private var name = ""
    @State private var address = ""
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Site name", text: $name)
                TextField("Address (shown on the report)", text: $address)
                Section {
                    Button("Delete site and its \(assets.filter { $0.siteID == site.id }.count) items", role: .destructive) { confirmingDelete = true }
                }
            }
            .navigationTitle("Edit Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { site.name = name; site.address = address; dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear { name = site.name; address = site.address }
            .confirmationDialog("Delete this site, all its equipment and every inspection?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    let siteID = site.id
                    let siteAssets = assets.filter { $0.siteID == siteID }
                    let ids = Set(siteAssets.map(\.id))
                    let history = (try? context.fetch(FetchDescriptor<Inspection>())) ?? []
                    history.filter { ids.contains($0.assetID) }.forEach(context.delete)
                    siteAssets.forEach(context.delete)
                    context.delete(site)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
