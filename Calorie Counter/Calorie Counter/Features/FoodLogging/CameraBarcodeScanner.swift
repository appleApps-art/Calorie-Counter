import AVFoundation
import UIKit

final class CameraBarcodeScanner: NSObject, BarcodeScanning {
    var onBarcodeScanned: ((String) -> Void)?
    var onScanFailed: ((Error) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "avo.barcode.scanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var isRunning = false
    private var lastEmittedCode: String?
    private var lastEmittedAt: Date = .distantPast

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
    }

    func layoutPreview(in view: UIView) {
        previewLayer?.frame = view.bounds
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
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.isRunning = false
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
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
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
        session.commitConfiguration()
        isConfigured = true
    }

    private func startSessionIfNeeded() {
        guard isConfigured, !session.isRunning else { return }
        session.startRunning()
        isRunning = true
    }
}

extension CameraBarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
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
