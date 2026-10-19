import Foundation

enum CSVExporter {
    static func inspectionsCSV(_ inspections: [Inspection], assets: [UUID: Asset], sites: [UUID: Site]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = ["date,site,tag,type,location,inspector,result,failed_items,notes"]
        for i in inspections.sorted(by: { $0.date < $1.date }) {
            let asset = assets[i.assetID]
            lines.append([
                iso.string(from: i.date),
                asset.flatMap { sites[$0.siteID]?.name } ?? "",
                asset?.tag ?? "",
                asset?.type.name ?? "",
                asset?.location ?? "",
                i.inspector,
                i.resultLabel,
                i.failedItems.joined(separator: "; "),
                i.notes,
            ].map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func assetsCSV(_ assets: [Asset], sites: [UUID: Site], inspections: [Inspection]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = ["site,tag,type,location,details,interval_days,last_inspected,next_due,expiry_items,notes"]
        for a in assets.sorted(by: { $0.tag < $1.tag }) {
            let last = DueCalculator.lastInspection(for: a, in: inspections)
            lines.append([
                sites[a.siteID]?.name ?? "",
                a.tag, a.type.name, a.location, a.details, String(a.intervalDays),
                last.map { iso.string(from: $0.date) } ?? "",
                iso.string(from: DueCalculator.nextDue(for: a, last: last)),
                a.datedItems.map { "\($0.label): \(Formatters.date.string(from: $0.date))" }.joined(separator: "; "),
                a.notes,
            ].map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func write(_ csv: String, suffix: String) throws -> URL {
        let url = ExportFile.temporaryURL(suffix: suffix, extension: "csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(suffix: String, extension ext: String) -> URL {
        let stamp = Formatters.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(suffix)-\(stamp)")
            .appendingPathExtension(ext)
    }
}
