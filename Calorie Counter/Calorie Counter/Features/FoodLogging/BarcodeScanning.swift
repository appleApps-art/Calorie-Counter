import Foundation

protocol BarcodeScanning: AnyObject {
    var onBarcodeScanned: ((String) -> Void)? { get set }
    var onScanFailed: ((Error) -> Void)? { get set }

    func startScanning()
    func stopScanning()
}

enum BarcodeScannerError: LocalizedError {
    case notConfigured
    case cameraUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L10n.tr("barcode.error.notConfigured")
        case .cameraUnavailable:
            return L10n.tr("barcode.error.cameraUnavailable")
        case .permissionDenied:
            return L10n.tr("barcode.error.permissionDenied")
        }
    }
}

final class UnconfiguredBarcodeScanner: BarcodeScanning {
    var onBarcodeScanned: ((String) -> Void)?
    var onScanFailed: ((Error) -> Void)?

    func startScanning() {
        onScanFailed?(BarcodeScannerError.notConfigured)
    }

    func stopScanning() {}
}
