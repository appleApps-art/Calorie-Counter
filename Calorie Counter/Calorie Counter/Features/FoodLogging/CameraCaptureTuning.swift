import AVFoundation

enum CameraCaptureTuning {
    static func bestBackCamera(closeRange _: Bool = false) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .back
        )
        for type in types {
            if let device = discovery.devices.first(where: { $0.deviceType == type }) {
                return device
            }
        }
        return discovery.devices.first
    }

    static func applyVideoPreset(_ session: AVCaptureSession, preferPhoto: Bool) {
        let presets: [AVCaptureSession.Preset]
        if preferPhoto {
            presets = [.photo, .hd4K3840x2160, .hd1920x1080, .high]
        } else {
            presets = [.hd4K3840x2160, .hd1920x1080, .high, .photo]
        }
        applyFirstAvailablePreset(presets, to: session)
    }

    static func applyBarcodePreset(_ session: AVCaptureSession) {
        applyFirstAvailablePreset([.hd1920x1080, .high, .hd1280x720, .photo], to: session)
    }

    private static func applyFirstAvailablePreset(_ presets: [AVCaptureSession.Preset], to session: AVCaptureSession) {
        for preset in presets where session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
            return
        }
    }

    static func configureDevice(_ device: AVCaptureDevice, closeRange: Bool) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = !closeRange
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = closeRange ? .near : .none
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.activeFormat.videoMaxZoomFactor
            let zoom: CGFloat
            if closeRange, let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first {
                zoom = CGFloat(truncating: switchOver as NSNumber)
            } else if closeRange {
                zoom = max(minZoom, 1)
            } else {
                zoom = minZoom
            }
            device.videoZoomFactor = min(max(zoom, minZoom), maxZoom)
            device.unlockForConfiguration()
        } catch {
            device.unlockForConfiguration()
        }
    }

    static func focus(device: AVCaptureDevice, on devicePoint: CGPoint) {
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
            device.unlockForConfiguration()
        } catch {
            device.unlockForConfiguration()
        }
    }

    static func applyMaxPhotoQuality(to output: AVCapturePhotoOutput, device: AVCaptureDevice?) {
        output.maxPhotoQualityPrioritization = .quality
        let dimensions = device?.activeFormat.supportedMaxPhotoDimensions ?? []
        if let max = dimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            output.maxPhotoDimensions = max
        }
    }

    static func maxQualitySettings(for output: AVCapturePhotoOutput) -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        if output.maxPhotoQualityPrioritization.rawValue >= AVCapturePhotoOutput.QualityPrioritization.quality.rawValue {
            settings.photoQualityPrioritization = .quality
        } else {
            settings.photoQualityPrioritization = output.maxPhotoQualityPrioritization
        }
        let dimensions = output.maxPhotoDimensions
        if dimensions.width > 0, dimensions.height > 0 {
            settings.maxPhotoDimensions = dimensions
        }
        return settings
    }
}
