import Foundation
import UIKit

protocol FoodPhotoCapturing: AnyObject {
    var onPhotoCaptured: ((Data) -> Void)? { get set }
    var onCaptureFailed: ((Error) -> Void)? { get set }
    var onSessionRunning: (() -> Void)? { get set }
    var isTorchAvailable: Bool { get }
    var isTorchOn: Bool { get }

    func attachPreview(to view: UIView)
    func layoutPreview(in view: UIView)
    func startCapture()
    func stopCapture()
    func captureStillPhoto(scanFrameInPreview frame: CGRect)
    func setTorchOn(_ on: Bool)
    func setLivePreviewHidden(_ hidden: Bool)
}

extension FoodPhotoCapturing {
    func captureFullFramePhoto() {
        captureStillPhoto(scanFrameInPreview: .zero)
    }
}

enum FoodPhotoCaptureError: LocalizedError {
    case notConfigured
    case cameraUnavailable
    case permissionDenied
    case noImageData

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L10n.tr("photo.error.notConfigured")
        case .cameraUnavailable:
            return L10n.tr("photo.error.cameraUnavailable")
        case .permissionDenied:
            return L10n.tr("photo.error.permissionDenied")
        case .noImageData:
            return L10n.tr("photo.error.noImage")
        }
    }
}

final class UnconfiguredFoodPhotoCapturer: FoodPhotoCapturing {
    var onPhotoCaptured: ((Data) -> Void)?
    var onCaptureFailed: ((Error) -> Void)?
    var onSessionRunning: (() -> Void)?
    var isTorchAvailable: Bool { false }
    var isTorchOn: Bool { false }

    func attachPreview(to view: UIView) {}
    func layoutPreview(in view: UIView) {}

    func startCapture() {
        onCaptureFailed?(FoodPhotoCaptureError.notConfigured)
    }

    func stopCapture() {}
    func captureStillPhoto(scanFrameInPreview frame: CGRect) {
        onCaptureFailed?(FoodPhotoCaptureError.notConfigured)
    }

    func setTorchOn(_ on: Bool) {}
    func setLivePreviewHidden(_ hidden: Bool) {}
}
