import UIKit

/// The inspection report for one site: status of every asset, failures, upcoming service dates, full log.
enum ReportExporter {
    static func export(site: Site, assets: [Asset], inspections: [Inspection], from start: Date, to end: Date = .now) throws -> URL {
        let siteAssets = assets.filter { $0.siteID == site.id && $0.isActive }.sorted { $0.tag < $1.tag }
        let ids = Set(siteAssets.map(\.id))
        let periodInspections = inspections.filter { ids.contains($0.assetID) && $0.date >= start && $0.date <= end }.sorted { $0.date < $1.date }
        let assetsByID = Dictionary(uniqueKeysWithValues: siteAssets.map { ($0.id, $0) })
        let summary = DueCalculator.summary(assets: siteAssets, inspections: inspections, from: start, now: end)
        let inspectors = Set(periodInspections.map(\.inspector).filter { !$0.isEmpty }).sorted()

        let footer = "\(AppConfig.appName) · inspections recorded by the facility's own staff · not a certification"
        return try PDFCanvas.render(footer: footer) { pdf in
            pdf.title("Safety equipment inspection report")
            pdf.subtitle("\(site.name)\(site.address.isEmpty ? "" : " · \(site.address)") · \(Formatters.date.string(from: start)) to \(Formatters.date.string(from: end)) · generated \(Formatters.dateTime.string(from: .now))")

            pdf.heading("Summary")
            pdf.keyValues([
                ("Equipment on record", "\(summary.assets)"),
                ("Inspections in period", "\(summary.inspectionsInPeriod)"),
                ("Overdue today", "\(summary.overdue)"),
                ("Never inspected", "\(summary.neverInspected)"),
                ("Needed attention in period", "\(summary.failuresInPeriod)"),
                ("Service dates within \(AppConfig.expiryWarningDays) days", "\(summary.expiringSoon)"),
                ("Inspectors", inspectors.isEmpty ? "—" : inspectors.joined(separator: ", ")),
            ])

            pdf.heading("Equipment status")
            pdf.table(
                headers: ["Tag", "Type", "Location", "Last inspected", "Result", "Next due"],
                widths: [0.11, 0.17, 0.27, 0.16, 0.14, 0.15],
                rows: siteAssets.map { asset in
                    let last = DueCalculator.lastInspection(for: asset, in: inspections)
                    let state = DueCalculator.state(for: asset, last: last, now: end)
                    let due: String
                    switch state {
                    case .neverInspected: due = "Never inspected"
                    case .overdue(let d): due = "OVERDUE \(Formatters.days(d))"
                    case .dueSoon, .ok: due = Formatters.date.string(from: DueCalculator.nextDue(for: asset, last: last))
                    }
                    return [asset.tag, asset.type.name, asset.location,
                            last.map { Formatters.date.string(from: $0.date) } ?? "—",
                            last?.resultLabel ?? "—", due]
                }
            )

            pdf.heading("Items that needed attention")
            let failures = periodInspections.filter { !$0.passed }
            pdf.table(
                headers: ["Date", "Tag", "Failed items", "Notes"],
                widths: [0.16, 0.12, 0.42, 0.30],
                rows: failures.map { [Formatters.date.string(from: $0.date), assetsByID[$0.assetID]?.tag ?? "", $0.failedItems.joined(separator: "; "), $0.notes] }
            )
            for f in failures {
                if let data = f.photo, let image = UIImage(data: data) {
                    pdf.image(image, caption: "\(assetsByID[f.assetID]?.tag ?? "") · \(Formatters.dateTime.string(from: f.date))")
                }
            }

            pdf.heading("Upcoming service and expiry dates")
            let dated = siteAssets.flatMap { asset in asset.datedItems.map { (asset.tag, $0.label, $0.date) } }.sorted { $0.2 < $1.2 }
            pdf.table(
                headers: ["Tag", "Item", "Date"],
                widths: [0.2, 0.5, 0.3],
                rows: dated.map { [$0.0, $0.1, Formatters.date.string(from: $0.2)] }
            )

            pdf.heading("Inspection log")
            pdf.table(
                headers: ["Date", "Tag", "Inspector", "Result", "Failed items / notes"],
                widths: [0.18, 0.12, 0.18, 0.14, 0.38],
                rows: periodInspections.map { i in
                    [Formatters.dateTime.string(from: i.date), assetsByID[i.assetID]?.tag ?? "", i.inspector, i.resultLabel,
                     ([i.failedItems.joined(separator: "; "), i.notes].filter { !$0.isEmpty }).joined(separator: " · ")]
                }
            )

            pdf.spacer(10)
            pdf.paragraph(AppConfig.disclaimer, color: .darkGray)
        }
    }
}
