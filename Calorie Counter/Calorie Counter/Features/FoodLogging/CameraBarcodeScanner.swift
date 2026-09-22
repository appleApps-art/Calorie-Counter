import AVFoundation
import CoreImage
import UIKit

final class CameraBarcodeScanner: NSObject, BarcodeScanning {
    var onBarcodeScanned: ((String) -> Void)?
    var onScanFailed: ((Error) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "bity.barcode.scanner.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "bity.barcode.scanner.video")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var isConfigured = false
    private var isRunning = false
    private var acceptsScans = true
    private var lastEmittedCode: String?
    private var lastEmittedAt: Date = .distantPast
    private var lastInterestRect: CGRect = .zero
    private var lastSubjectFocusAt: Date = .distantPast
    private var subjectAreaObserver: NSObjectProtocol?
    /// The newest camera frame, kept so a read code can freeze the screen on the frame it came from.
    private var latestFrame: CVPixelBuffer?
    private let frameContext = CIContext()

    func attachPreview(to view: UIView) {
        let layer = previewLayer ?? AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        if previewLayer == nil {
            view.layer.insertSublayer(layer, at: 0)
            previewLayer = layer
        } else if layer.superlayer !== view.layer {
            layer.removeFromSuperlayer()
            view.layer.insertSublayer(layer, at: 0)
        }
        previewLayer = layer
        applyPortraitRotation(layer.connection)
    }

    func layoutPreview(in view: UIView) {
        previewLayer?.frame = view.bounds
        applyPortraitRotation(previewLayer?.connection)
    }

    func updateInterestRect(_ rectInPreview: CGRect) {
        guard let previewLayer else { return }
        let rounded = rectInPreview.integral
        guard rounded.width > 8, rounded.height > 8 else { return }
        if rounded == lastInterestRect { return }
        lastInterestRect = rounded
        let converted = previewLayer.metadataOutputRectConverted(fromLayerRect: rounded)
        sessionQueue.async { [weak self] in
            self?.metadataOutput?.rectOfInterest = converted
        }
    }

    func setAcceptsScans(_ accepts: Bool) {
        acceptsScans = accepts
        if accepts {
            // The code just handled stays in front of the camera; it is read again only after a pause,
            // so a "not found" does not repeat in a loop while other codes still read at once.
            lastEmittedAt = Date()
        }
    }

    func setTorchOn(_ on: Bool) {
        sessionQueue.async { [weak self] in
            self?.setTorchOnLocked(on)
        }
    }

    /// The frame on screen right now, turned upright for the portrait preview.
    func freezeCurrentFrame(_ completion: @escaping (UIImage?) -> Void) {
        videoOutputQueue.async { [weak self] in
            var image: UIImage?
            if let self, let buffer = self.latestFrame {
                let frame = CIImage(cvPixelBuffer: buffer)
                if let cgImage = self.frameContext.createCGImage(frame, from: frame.extent) {
                    image = UIImage(cgImage: cgImage)
                }
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    func startScanning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.requestAccessAndStart()
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setTorchOnLocked(false)
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.isRunning = false
            self.videoOutputQueue.async { self.latestFrame = nil }
        }
    }

    deinit {
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
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
                        self.onScanFailed?(BarcodeScannerError.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.onScanFailed?(BarcodeScannerError.permissionDenied)
            }
        @unknown default:
            DispatchQueue.main.async { [weak self] in
                self?.onScanFailed?(BarcodeScannerError.cameraUnavailable)
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        CameraCaptureTuning.applyBarcodePreset(session)

        guard
            let device = CameraCaptureTuning.bestBackCamera(closeRange: true),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.onScanFailed?(BarcodeScannerError.cameraUnavailable)
            }
            return
        }
        session.addInput(input)
        captureDevice = device
        observeSubjectAreaChanges(for: device)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.onScanFailed?(BarcodeScannerError.cameraUnavailable)
            }
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        // Only the codes printed on food packs. QR codes and Code 39 on the same pack used to be
        // read first and ended in "invalid barcode" instead of the product.
        let supported: [AVMetadataObject.ObjectType] = [
            .ean13,
            .ean8,
            .upce,
            .itf14,
            .code128,
        ]
        output.metadataObjectTypes = supported.filter { output.availableMetadataObjectTypes.contains($0) }
        applyPortraitRotation(output.connection(with: .video))
        if let connection = output.connection(with: .video), connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .off
        }
        metadataOutput = output
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            applyPortraitRotation(videoOutput.connection(with: .video))
            if let connection = videoOutput.connection(with: .video), connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .off
            }
        }
        CameraCaptureTuning.configureDevice(device, closeRange: true)
        session.commitConfiguration()
        isConfigured = true
    }

    private func startSessionIfNeeded() {
        guard isConfigured, !session.isRunning else { return }
        session.startRunning()
        isRunning = true
        if let device = captureDevice {
            CameraCaptureTuning.focus(device: device, on: CGPoint(x: 0.5, y: 0.5))
        }
    }

    private func observeSubjectAreaChanges(for device: AVCaptureDevice) {
        if let subjectAreaObserver {
            NotificationCenter.default.removeObserver(subjectAreaObserver)
        }
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceSubjectAreaDidChange,
            object: device,
            queue: .main
        ) { [weak self] _ in
            self?.sessionQueue.async {
                guard let self, let device = self.captureDevice else { return }
                let now = Date()
                guard now.timeIntervalSince(self.lastSubjectFocusAt) > 0.45 else { return }
                self.lastSubjectFocusAt = now
                CameraCaptureTuning.focus(device: device, on: CGPoint(x: 0.5, y: 0.5))
            }
        }
    }


    private func applyPortraitRotation(_ connection: AVCaptureConnection?) {
        guard let connection, connection.isVideoRotationAngleSupported(90) else { return }
        connection.videoRotationAngle = 90
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


}

extension CameraBarcodeScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        latestFrame = CMSampleBufferGetImageBuffer(sampleBuffer)
    }
}

extension CameraBarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard acceptsScans else { return }
        // A partial or damaged read fails its check digit and is skipped; the next frame usually
        // reads it whole. Of several codes, the one nearest the middle of the frame wins.
        let codes = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .filter { $0.stringValue.map(BarcodeNormalization.isProductCode) ?? false }
        let center = CGPoint(x: 0.5, y: 0.5)
        guard let value = codes.min(by: {
            hypot($0.bounds.midX - center.x, $0.bounds.midY - center.y)
                < hypot($1.bounds.midX - center.x, $1.bounds.midY - center.y)
        })?.stringValue else { return }

        let now = Date()
        if value == lastEmittedCode, now.timeIntervalSince(lastEmittedAt) < 2.5 {
            return
        }
        lastEmittedCode = value
        lastEmittedAt = now
        onBarcodeScanned?(value)
    }
}
