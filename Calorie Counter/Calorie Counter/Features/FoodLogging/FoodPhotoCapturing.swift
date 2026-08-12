import Foundation
import UIKit

protocol FoodPhotoCapturing: AnyObject {
    var onPhotoCaptured: ((Data) -> Void)? { get set }
    var onCaptureFailed: ((Error) -> Void)? { get set }

    func startCapture()
    func stopCapture()
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

    func startCapture() {
        onCaptureFailed?(FoodPhotoCaptureError.notConfigured)
    }

    func stopCapture() {}
}
