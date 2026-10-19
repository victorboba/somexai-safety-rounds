import SwiftUI
import VisionKit

/// Live QR scanner for the printed labels. Needs a real camera; the simulator shows a message instead.
struct ScannerSheet: View {
    let onAsset: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var unrecognized = false

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ScannerView { payload in
                        if let url = URL(string: payload), url.scheme == AppConfig.urlScheme, let id = UUID(uuidString: url.lastPathComponent) {
                            onAsset(id)
                        } else {
                            unrecognized = true
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    ContentUnavailableView("Camera not available", systemImage: "camera",
                                           description: Text("Scanning needs a device camera. You can also scan a label with the iPhone Camera app; it opens the checklist directly."))
                }
            }
            .navigationTitle("Scan Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Not a Safety Rounds label", isPresented: $unrecognized) { Button("OK") {} }
        }
    }
}

private struct ScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
                                                recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var handled = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !handled else { return }
            for item in addedItems {
                if case .barcode(let code) = item, let value = code.payloadStringValue {
                    handled = true
                    scanner.stopScanning()
                    onCode(value)
                    return
                }
            }
        }
    }
}
