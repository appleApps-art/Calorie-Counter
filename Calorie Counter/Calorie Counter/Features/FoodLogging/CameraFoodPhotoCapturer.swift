import AVFoundation
import UIKit

final class CameraFoodPhotoCapturer: NSObject, FoodPhotoCapturing {
    var onPhotoCaptured: ((Data) -> Void)?
    var onCaptureFailed: ((Error) -> Void)?
    var onSessionRunning: (() -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "bity.food.photo.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private var isConfigured = false
    private weak var previewView: UIView?

    var isTorchAvailable: Bool {
        captureDevice?.hasTorch == true
    }

    var isTorchOn: Bool {
        captureDevice?.torchMode == .on
    }

    func attachPreview(to view: UIView) {
        previewView = view
        let layer = previewLayer ?? AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        if previewLayer == nil {
            view.layer.insertSublayer(layer, at: 0)
        } else if layer.superlayer !== view.layer {
            layer.removeFromSuperlayer()
            view.layer.insertSublayer(layer, at: 0)
        }
        previewLayer = layer
    }

    func layoutPreview(in view: UIView) {
        previewLayer?.frame = view.bounds
        applyPortraitRotation(previewLayer?.connection)
    }

    func startCapture() {
        sessionQueue.async { [weak self] in
            self?.requestAccessAndStart()
        }
    }

    func stopCapture() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setTorchOnLocked(false)
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func captureStillPhoto(scanFrameInPreview _: CGRect) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else {
                DispatchQueue.main.async {
                    self.onCaptureFailed?(FoodPhotoCaptureError.cameraUnavailable)
                }
                return
            }
            applyPortraitRotation(self.photoOutput.connection(with: .video))
            let settings = CameraCaptureTuning.maxQualitySettings(for: self.photoOutput)
            DispatchQueue.main.async {
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func setTorchOn(_ on: Bool) {
        sessionQueue.async { [weak self] in
            self?.setTorchOnLocked(on)
        }
    }

    func setLivePreviewHidden(_ hidden: Bool) {
        let apply: () -> Void = { [weak self] in
            self?.previewLayer?.isHidden = hidden
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureIfNeeded()
            startSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.sessionQueue.async {
                        self.configureIfNeeded()
                        self.startSessionIfNeeded()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.onCaptureFailed?(FoodPhotoCaptureError.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.onCaptureFailed?(FoodPhotoCaptureError.permissionDenied)
            }
        @unknown default:
            DispatchQueue.main.async { [weak self] in
                self?.onCaptureFailed?(FoodPhotoCaptureError.cameraUnavailable)
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        CameraCaptureTuning.applyVideoPreset(session, preferPhoto: true)

        guard
            let device = CameraCaptureTuning.bestBackCamera(),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.onCaptureFailed?(FoodPhotoCaptureError.cameraUnavailable)
            }
            return
        }
        session.addInput(input)
        captureDevice = device

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.onCaptureFailed?(FoodPhotoCaptureError.cameraUnavailable)
            }
            return
        }
        session.addOutput(photoOutput)
        CameraCaptureTuning.applyMaxPhotoQuality(to: photoOutput, device: device)
        CameraCaptureTuning.configureDevice(device, closeRange: false)
        applyPortraitRotation(photoOutput.connection(with: .video))
        session.commitConfiguration()
        isConfigured = true
    }

    private func applyPortraitRotation(_ connection: AVCaptureConnection?) {
        guard let connection, connection.isVideoRotationAngleSupported(90) else { return }
        connection.videoRotationAngle = 90
    }

    private func startSessionIfNeeded() {
        guard isConfigured, !session.isRunning else { return }
        session.startRunning()
        DispatchQueue.main.async { [weak self] in
            self?.onSessionRunning?()
        }
    }

    private func setTorchOnLocked(_ on: Bool) {
        guard let device = captureDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on, device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: 1)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            device.unlockForConfiguration()
        }
    }

    private func croppedJPEG(from photo: AVCapturePhoto) -> Data? {
        photo.fileDataRepresentation()
    }
}

extension CameraFoodPhotoCapturer: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            DispatchQueue.main.async { [weak self] in
                self?.onCaptureFailed?(error)
            }
            return
        }
        guard let data = croppedJPEG(from: photo), !data.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.onCaptureFailed?(FoodPhotoCaptureError.noImageData)
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(data)
        }
    }
}
