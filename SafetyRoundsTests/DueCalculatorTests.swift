import XCTest
@testable import SafetyRounds

@MainActor
final class DueCalculatorTests: XCTestCase {
    private let calendar = Calendar.current
    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))! }

    private func makeAsset(interval: Int = 30) -> Asset {
        let site = Site(name: "Main")
        let asset = Asset(site: site, type: .extinguisher, tag: "EXT-01")
        asset.intervalDays = interval
        return asset
    }

    func testNeverInspectedWhenNoHistory() {
        XCTAssertEqual(DueCalculator.state(for: makeAsset(), last: nil), .neverInspected)
    }

    func testOverdueCountsDaysPastInterval() {
        let asset = makeAsset()
        let last = Inspection(asset: asset, date: day(-35))
        XCTAssertEqual(DueCalculator.state(for: asset, last: last), .overdue(days: 5))
    }

    func testDueSoonWithinWindow() {
        let asset = makeAsset()
        let last = Inspection(asset: asset, date: day(-27))
        XCTAssertEqual(DueCalculator.state(for: asset, last: last), .dueSoon(days: 3))
    }

    func testOkBeyondWindow() {
        let asset = makeAsset()
        let last = Inspection(asset: asset, date: day(-2))
        XCTAssertEqual(DueCalculator.state(for: asset, last: last), .ok(days: 28))
    }

    func testWeeklyIntervalForEyewash() {
        let site = Site(name: "Main")
        let asset = Asset(site: site, type: .eyewash, tag: "EW-01")
        XCTAssertEqual(asset.intervalDays, 7)
        let last = Inspection(asset: asset, date: day(-8))
        XCTAssertEqual(DueCalculator.state(for: asset, last: last), .overdue(days: 1))
    }

    func testExpiringItemsFlagWithinThirtyDaysAndPast() {
        let asset = makeAsset()
        asset.expiries = [day(10), day(-3), day(200)]
        let items = DueCalculator.expiringItems(for: asset)
        XCTAssertEqual(items.map(\.label), ["Annual service due", "6-year maintenance due"])
        XCTAssertEqual(items.map(\.days), [10, -3])
    }

    func testSummaryCountsStatesAndFailures() {
        let a1 = makeAsset(), a2 = makeAsset(), a3 = makeAsset()
        let i1 = Inspection(asset: a1, date: day(-40))
        let i2 = Inspection(asset: a2, date: day(-5))
        i2.failedItems = ["Pressure gauge needle in the green"]
        let summary = DueCalculator.summary(assets: [a1, a2, a3], inspections: [i1, i2], from: day(-90))
        XCTAssertEqual(summary.assets, 3)
        XCTAssertEqual(summary.overdue, 1)
        XCTAssertEqual(summary.neverInspected, 1)
        XCTAssertEqual(summary.inspectionsInPeriod, 2)
        XCTAssertEqual(summary.failuresInPeriod, 1)
    }

    func testFailedItemsDrivePassFlag() {
        let asset = makeAsset()
        let inspection = Inspection(asset: asset)
        XCTAssertTrue(inspection.passed)
        inspection.failedItems = ["Pull pin and tamper seal intact"]
        XCTAssertFalse(inspection.passed)
        inspection.failedItems = []
        XCTAssertTrue(inspection.passed)
    }
}
