import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query(sort: \Asset.tag) private var assets: [Asset]
    @Query(sort: \Inspection.date, order: .reverse) private var inspections: [Inspection]

    @State private var selectedSiteID: UUID?
    @State private var period: Period = .days90
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    enum Period: String, CaseIterable, Identifiable {
        case days30 = "30 days", days90 = "90 days", year = "12 months"
        var id: String { rawValue }
        var days: Int { switch self { case .days30: 30; case .days90: 90; case .year: 365 } }
    }

    private var site: Site? { sites.first { $0.id == selectedSiteID } ?? sites.first }
    private var start: Date { Calendar.current.date(byAdding: .day, value: -(period.days - 1), to: Calendar.current.startOfDay(for: .now)) ?? .now }
    private var siteAssets: [Asset] { assets.filter { $0.siteID == site?.id && $0.isActive } }
    private var summary: DueCalculator.Summary { DueCalculator.summary(assets: siteAssets, inspections: inspections, from: start) }
    private var sitesByID: [UUID: Site] { Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) }) }
    private var assetsByID: [UUID: Asset] { Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) }) }

    var body: some View {
        NavigationStack {
            Group {
                if let site {
                    List {
                        if sites.count > 1 {
                            Section {
                                Picker("Site", selection: Binding(get: { site.id }, set: { selectedSiteID = $0 })) {
                                    ForEach(sites) { Text($0.name).tag($0.id) }
                                }
                            }
                        }
                        Section {
                            Picker("Period", selection: $period) { ForEach(Period.allCases) { Text($0.rawValue).tag($0) } }
                                .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                        }
                        Section("\(site.name) · \(Formatters.date.string(from: start)) to today") {
                            LabeledContent("Equipment on record", value: "\(summary.assets)")
                            LabeledContent("Inspections in period", value: "\(summary.inspectionsInPeriod)")
                            LabeledContent("Overdue today", value: "\(summary.overdue)").foregroundStyle(summary.overdue > 0 ? .red : .primary)
                            LabeledContent("Never inspected", value: "\(summary.neverInspected)").foregroundStyle(summary.neverInspected > 0 ? .red : .primary)
                            LabeledContent("Needed attention", value: "\(summary.failuresInPeriod)").foregroundStyle(summary.failuresInPeriod > 0 ? .orange : .primary)
                            LabeledContent("Service dates within \(AppConfig.expiryWarningDays) days", value: "\(summary.expiringSoon)").foregroundStyle(summary.expiringSoon > 0 ? .orange : .primary)
                        }
                        Section("Export") {
                            Button { export { try ReportExporter.export(site: site, assets: assets, inspections: inspections, from: start) } } label: {
                                Label("Inspection report PDF", systemImage: "doc.richtext")
                            }
                            Button { export { try LabelSheetExporter.export(assets: siteAssets, sites: sitesByID) } } label: {
                                Label("QR label sheet PDF", systemImage: "qrcode")
                            }
                            Button { export { try CSVExporter.write(CSVExporter.inspectionsCSV(inspections.filter { assetsByID[$0.assetID]?.siteID == site.id && $0.date >= start }, assets: assetsByID, sites: sitesByID), suffix: "inspections") } } label: {
                                Label("Inspections CSV", systemImage: "tablecells")
                            }
                            Button { export { try CSVExporter.write(CSVExporter.assetsCSV(siteAssets, sites: sitesByID, inspections: inspections), suffix: "equipment") } } label: {
                                Label("Equipment list CSV", systemImage: "tablecells")
                            }
                        }
                        Section { Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary) }
                    }
                } else {
                    ContentUnavailableView("No site yet", systemImage: "doc.text", description: Text("Add equipment on the Equipment tab to start a report."))
                }
            }
            .navigationTitle("Report")
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private func export(_ make: () throws -> URL) {
        do { exportFile = ExportFile(url: try make()) } catch { exportError = error.localizedDescription }
    }
}
