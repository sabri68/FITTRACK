import SwiftUI
import VisionKit

/// Live camera barcode scanner based on VisionKit's DataScannerViewController.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    @MainActor static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    @MainActor static var unavailableReason: String {
        if !DataScannerViewController.isSupported {
            return "Le scan de codes-barres n'est pas pris en charge sur cet appareil (le simulateur n'a pas de caméra)."
        }
        return "L'accès à l'appareil photo est refusé. Autorisez-le dans Réglages › FitTrack › Appareil photo."
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        DispatchQueue.main.async { try? controller.startScanning() }
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var delivered = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue, !value.isEmpty {
                    delivered = true
                    dataScanner.stopScanning()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onScan(value)
                    return
                }
            }
        }
    }
}
