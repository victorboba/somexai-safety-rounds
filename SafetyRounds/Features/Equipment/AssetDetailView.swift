import SwiftUI
import SwiftData

/// One asset: status, its QR code, service dates and the inspection history.
struct AssetDetailView: View {
    let asset: Asset

    @Environment(\.modelContext) private var context
    @Query(sort: \Inspection.date, order: .reverse) private var allInspections: [Inspection]
    @Query(sort: \Site.createdAt) private var sites: [Site]

    @State private var inspecting = false
    @State private var editing = false
    @State private var editingInspection: Inspection?
    @State private var showingQR = false

    private var inspections: [Inspection] { allInspections.filter { $0.assetID == asset.id } }
    private var state: DueState { DueCalculator.state(for: asset, last: inspections.first) }

    var body: some View {
        List {
            Section {
                AssetRow(asset: asset, state: state, siteName: sites.first { $0.id == asset.siteID }?.name, lastResultPassed: inspections.first?.passed)
                if !asset.details.isEmpty { LabeledContent("Details", value: asset.details) }
                LabeledContent("Interval", value: "every \(Formatters.days(asset.intervalDays))")
                LabeledContent("Next due", value: Formatters.date.string(from: DueCalculator.nextDue(for: asset, last: inspections.first)))
                if !asset.notes.isEmpty { Text(asset.notes).font(.footnote).foregroundStyle(.secondary) }
            }

            Section {
                Button { inspecting = true } label: { Label("Inspect now", systemImage: "checklist") }
                Button { showingQR = true } label: { Label("Show QR label", systemImage: "qrcode") }
            }

            if !asset.datedItems.isEmpty {
                Section("Service and expiry dates") {
                    ForEach(asset.datedItems, id: \.label) { item in
                        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: item.date)).day ?? 0
                        LabeledContent(item.label, value: Formatters.date.string(from: item.date))
                            .foregroundStyle(days < 0 ? .red : days <= AppConfig.expiryWarningDays ? .orange : .primary)
                    }
                }
            }

            Section("History (\(inspections.count))") {
                if inspections.isEmpty {
                    Text("Not inspected yet.").foregroundStyle(.secondary)
                }
                ForEach(inspections) { inspection in
                    Button { editingInspection = inspection } label: {
                        HStack(alignment: .top) {
                            Image(systemName: inspection.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(inspection.passed ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Formatters.dateTime.string(from: inspection.date))
                                Text([inspection.inspector, inspection.failedItems.joined(separator: "; "), inspection.notes].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in offsets.map { inspections[$0] }.forEach(context.delete) }
            }
        }
        .navigationTitle(asset.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
        .sheet(isPresented: $inspecting) { InspectionSheet(asset: asset) }
        .sheet(isPresented: $editing) { AssetEditorView(asset: asset) }
        .sheet(item: $editingInspection) { InspectionSheet(asset: asset, existing: $0) }
        .sheet(isPresented: $showingQR) { QRLabelSheet(asset: asset, siteName: sites.first { $0.id == asset.siteID }?.name ?? "") }
    }
}

/// A single label, big enough to photograph or share; the sheet of all labels comes from the Equipment tab.
struct QRLabelSheet: View {
    let asset: Asset
    let siteName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let image = QRCode.image(for: AppConfig.assetURL(asset.id).absoluteString, size: 800) {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260)
                        .accessibilityLabel("QR code for \(asset.title)")
                }
                Text(asset.title).font(.title.bold())
                Text([asset.type.name, asset.location].filter { !$0.isEmpty }.joined(separator: " · ")).foregroundStyle(.secondary)
                Text(siteName).font(.footnote).foregroundStyle(.secondary)
                Text("Scan with the iPhone Camera or the in-app scanner to open this checklist.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 8)
                Spacer()
            }
            .padding(24)
            .navigationTitle("QR Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    if let image = QRCode.image(for: AppConfig.assetURL(asset.id).absoluteString, size: 1200) {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(asset.title, image: Image(uiImage: image)))
                    }
                }
            }
        }
    }
}
