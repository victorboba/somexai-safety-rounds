import UIKit

/// A printable sheet of QR labels, 3 x 4 per US Letter page, each 2.5 inches square with a cut line.
/// Scanning a label with the Camera app or the in-app scanner opens that asset's checklist.
enum LabelSheetExporter {
    static func export(assets: [Asset], sites: [UUID: Site]) throws -> URL {
        let url = ExportFile.temporaryURL(suffix: "labels", extension: "pdf")
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let columns = 3, rows = 4
        let margin: CGFloat = 36
        let cell = CGSize(width: (page.width - margin * 2) / CGFloat(columns), height: (page.height - margin * 2) / CGFloat(rows))
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let sorted = assets.sorted { ($0.siteID.uuidString, $0.tag) < ($1.siteID.uuidString, $1.tag) }

        try renderer.writePDF(to: url) { context in
            for (index, asset) in sorted.enumerated() {
                let slot = index % (columns * rows)
                if slot == 0 { context.beginPage() }
                let origin = CGPoint(x: margin + CGFloat(slot % columns) * cell.width, y: margin + CGFloat(slot / columns) * cell.height)
                let box = CGRect(origin: origin, size: cell).insetBy(dx: 4, dy: 4)

                context.cgContext.setStrokeColor(UIColor(white: 0.8, alpha: 1).cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.setLineDash(phase: 0, lengths: [3, 3])
                context.cgContext.stroke(box)
                context.cgContext.setLineDash(phase: 0, lengths: [])

                let qrSize: CGFloat = 96
                if let qr = QRCode.image(for: AppConfig.assetURL(asset.id).absoluteString, size: qrSize * 4) {
                    qr.draw(in: CGRect(x: box.midX - qrSize / 2, y: box.minY + 12, width: qrSize, height: qrSize))
                }
                var y = box.minY + 12 + qrSize + 6
                let center = NSMutableParagraphStyle()
                center.alignment = .center
                center.lineBreakMode = .byTruncatingTail
                func line(_ text: String, font: UIFont, color: UIColor = .black, height: CGFloat) {
                    text.draw(in: CGRect(x: box.minX + 6, y: y, width: box.width - 12, height: height),
                              withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: center])
                    y += height
                }
                line(asset.tag.isEmpty ? asset.type.name : asset.tag, font: .boldSystemFont(ofSize: 16), height: 20)
                line(asset.type.name, font: .systemFont(ofSize: 10), color: .darkGray, height: 13)
                line(asset.location, font: .systemFont(ofSize: 9), color: .darkGray, height: 12)
                line(sites[asset.siteID]?.name ?? "", font: .systemFont(ofSize: 9), color: .darkGray, height: 12)
                line("Scan to inspect · \(AppConfig.appName)", font: .systemFont(ofSize: 7), color: .gray, height: 10)
            }
        }
        return url
    }
}
