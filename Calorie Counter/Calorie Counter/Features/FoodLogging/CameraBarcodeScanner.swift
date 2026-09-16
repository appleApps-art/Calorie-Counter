import AVFoundation
import CoreImage
import UIKit

final class CameraBarcodeScanner: NSObject, BarcodeScanning {
    var onBarcodeScanned: ((String) -> Void)?
    var onScanFailed: ((Error) -> Void)?
    var onStillPhotoCaptured: ((Data) -> Void)?

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
    private var wantsStillFrame = false
    private var stillCropInPreview: CGRect = .zero
    private var stillPreviewBounds: CGRect = .zero

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
            lastEmittedCode = nil
            lastEmittedAt = .distantPast
        }
    }

    func setTorchOn(_ on: Bool) {
        sessionQueue.async { [weak self] in
            self?.setTorchOnLocked(on)
        }
    }

    func captureStillPhoto(scanFrameInPreview: CGRect) {
        let previewBounds = previewLayer?.bounds ?? .zero
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else {
                DispatchQueue.main.async {
                    self.onScanFailed?(BarcodeScannerError.cameraUnavailable)
                }
                return
            }
            self.videoOutputQueue.async {
                self.stillCropInPreview = scanFrameInPreview
                self.stillPreviewBounds = previewBounds
                self.wantsStillFrame = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.finishStillCaptureIfNeeded()
            }
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
        let supported: [AVMetadataObject.ObjectType] = [
            .ean8,
            .ean13,
            .upce,
            .code128,
            .code39,
            .qr,
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

    private func finishStillCaptureIfNeeded() {
        videoOutputQueue.async { [weak self] in
            guard let self, self.wantsStillFrame else { return }
            self.wantsStillFrame = false
            DispatchQueue.main.async {
                self.emitPreviewSnapshot(cropInPreview: self.stillCropInPreview)
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

    private func emitPreviewSnapshot(cropInPreview: CGRect) {
        guard let previewLayer, previewLayer.bounds.width > 1, previewLayer.bounds.height > 1 else {
            onScanFailed?(BarcodeScannerError.cameraUnavailable)
            return
        }
        let renderer = UIGraphicsImageRenderer(bounds: previewLayer.bounds)
        let image = renderer.image { context in
            previewLayer.render(in: context.cgContext)
        }
        let cropped = crop(image, to: cropInPreview, in: previewLayer.bounds) ?? image
        guard let data = cropped.jpegData(compressionQuality: 0.95), !data.isEmpty else {
            onScanFailed?(BarcodeScannerError.cameraUnavailable)
            return
        }
        onStillPhotoCaptured?(data)
    }

    private func crop(_ image: UIImage, to rect: CGRect, in previewBounds: CGRect) -> UIImage? {
        guard rect.width > 8, rect.height > 8, previewBounds.width > 1, previewBounds.height > 1 else {
            return image
        }
        let scaleX = image.size.width / previewBounds.width
        let scaleY = image.size.height / previewBounds.height
        let cropRect = CGRect(
            x: rect.minX * scaleX,
            y: rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral.intersection(CGRect(origin: .zero, size: image.size))
        guard cropRect.width > 8, cropRect.height > 8, let cgImage = image.cgImage else {
            return image
        }
        let pixelScale = image.scale
        let pixelRect = CGRect(
            x: cropRect.minX * pixelScale,
            y: cropRect.minY * pixelScale,
            width: cropRect.width * pixelScale,
            height: cropRect.height * pixelScale
        ).integral.intersection(
            CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        )
        guard pixelRect.width > 8, pixelRect.height > 8, let cropped = cgImage.cropping(to: pixelRect) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension CameraBarcodeScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard wantsStillFrame, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        wantsStillFrame = false
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            DispatchQueue.main.async { [weak self] in
                self?.emitPreviewSnapshot(cropInPreview: self?.stillCropInPreview ?? .zero)
            }
            return
        }
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        guard let data = image.jpegData(compressionQuality: 0.92), !data.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.onScanFailed?(BarcodeScannerError.cameraUnavailable)
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onStillPhotoCaptured?(data)
        }
    }
}

extension CameraBarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard acceptsScans else { return }
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = object.stringValue,
            !value.isEmpty
        else { return }

        let now = Date()
        if value == lastEmittedCode, now.timeIntervalSince(lastEmittedAt) < 2.0 {
            return
        }
        lastEmittedCode = value
        lastEmittedAt = now
        onBarcodeScanned?(value)
    }
}
