import XCTest
import SwiftData
import PDFKit
@testable import SafetyRounds

@MainActor
final class ExportTests: XCTestCase {
    private func sampleContainer() throws -> ModelContainer {
        let schema = Schema([Site.self, Asset.self, Inspection.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        SampleData.insert(into: container.mainContext)
        return container
    }

    func testReportRendersWithSampleData() throws {
        let container = try sampleContainer()
        let context = container.mainContext
        let sites = try context.fetch(FetchDescriptor<Site>())
        let assets = try context.fetch(FetchDescriptor<Asset>())
        let inspections = try context.fetch(FetchDescriptor<Inspection>())
        let site = try XCTUnwrap(sites.first { $0.name.contains("Riverside") })
        XCTAssertGreaterThan(inspections.count, 50)

        let url = try ReportExporter.export(site: site, assets: assets, inspections: inspections, from: Calendar.current.date(byAdding: .day, value: -90, to: .now)!)
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThanOrEqual(document.pageCount, 2)
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
        XCTAssertTrue(text.contains("EXT-03"))
        XCTAssertTrue(text.contains("OVERDUE"))
        XCTAssertTrue(text.contains("Lamp out"))
        XCTAssertTrue(text.contains("Pads expire"))
    }

    func testLabelSheetHasOnePagePerTwelveLabels() throws {
        let container = try sampleContainer()
        let context = container.mainContext
        let sites = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Site>()).map { ($0.id, $0) })
        let assets = try context.fetch(FetchDescriptor<Asset>())
        let url = try LabelSheetExporter.export(assets: assets, sites: sites)
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(document.pageCount, Int(ceil(Double(assets.count) / 12)))
    }

    func testInspectionCSVHasHeaderAndRows() throws {
        let container = try sampleContainer()
        let context = container.mainContext
        let sites = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Site>()).map { ($0.id, $0) })
        let assets = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Asset>()).map { ($0.id, $0) })
        let inspections = try context.fetch(FetchDescriptor<Inspection>())
        let csv = CSVExporter.inspectionsCSV(inspections, assets: assets, sites: sites)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, inspections.count + 1)
        XCTAssertTrue(lines[0].hasPrefix("date,site,tag,type"))
        XCTAssertTrue(csv.contains("\"Needs attention\""))
    }

    func testQRCodeRoundTripsAssetURL() throws {
        let id = UUID()
        let image = try XCTUnwrap(QRCode.image(for: AppConfig.assetURL(id).absoluteString, size: 300))
        XCTAssertEqual(image.size.width, image.size.height)
        XCTAssertGreaterThan(image.size.width, 100)
    }
}
