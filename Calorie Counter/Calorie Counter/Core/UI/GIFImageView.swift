import ImageIO
import UIKit

final class GIFImageView: UIImageView {
    var playsOnce = false
    /// How many times a looping GIF plays before it stops on its last frame and reports
    /// `onFinished`; nil repeats until it is stopped.
    var loopLimit: Int?
    var onFinished: (() -> Void)?
    var onReachedEnd: (() -> Void)?
    private(set) var duration: TimeInterval = 0
    var hasAnimatedGIF: Bool { gifData != nil && frameCount > 1 }

    private var gifData: Data?
    private var frameCount = 0
    private var animationID = 0
    private var didFinish = false
    private var completedLoops = 0
    private var frozenImage: UIImage?

    deinit {
        animationID += 1
    }

    func loadGIF(named name: String) {
        stopAnimatingGIF()
        gifData = nil
        frameCount = 0
        duration = 0
        didFinish = false
        frozenImage = nil
        isOpaque = false
        backgroundColor = .clear

        if let url = Self.gifURL(named: name),
           let data = try? Data(contentsOf: url),
           let source = CGImageSourceCreateWithData(data as CFData, nil) {
            gifData = data
            frameCount = CGImageSourceGetCount(source)
            duration = Self.duration(of: data, frameCount: frameCount)
            if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                image = UIImage(cgImage: cgImage)
            }
            return
        }

        image = UIImage(named: name)
    }

    func startAnimatingGIF() {
        guard let gifData, frameCount > 1 else {
            finishIfNeeded()
            notifyReachedEnd()
            return
        }
        animationID += 1
        let id = animationID
        didFinish = false
        frozenImage = nil
        completedLoops = 0
        let lastIndex = frameCount - 1
        let loops = playsOnce ? 1 : loopLimit.map { max($0, 1) }

        let status = CGAnimateImageDataWithBlock(gifData as CFData, nil) { [weak self] index, cgImage, stop in
            guard let self else {
                stop.pointee = true
                return
            }
            if self.animationID != id || self.didFinish {
                stop.pointee = true
                self.holdFrozenFrame()
                return
            }
            if loops != nil, index == 0, let frozenImage = self.frozenImage {
                self.freeze(frozenImage, stop: stop)
                return
            }
            if let loops, index >= lastIndex {
                self.completedLoops += 1
                if self.completedLoops >= loops {
                    let durable = Self.copyImage(cgImage)
                    self.freeze(durable, stop: stop)
                    return
                }
            }
            self.image = UIImage(cgImage: cgImage)
            if index >= lastIndex, loops != 1 {
                self.notifyReachedEnd()
            }
        }
        if status != .zero {
            finishIfNeeded()
            notifyReachedEnd()
        }
    }

    func stopAnimatingGIF() {
        animationID += 1
        holdFrozenFrame()
    }

    private func freeze(_ frame: UIImage, stop: UnsafeMutablePointer<Bool>) {
        frozenImage = frame
        image = frame
        stop.pointee = true
        animationID += 1
        holdFrozenFrame()
        DispatchQueue.main.async { [weak self] in
            self?.holdFrozenFrame()
        }
        finishIfNeeded()
    }

    private func holdFrozenFrame() {
        if let frozenImage {
            image = frozenImage
        }
    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        let callback = onFinished
        if Thread.isMainThread {
            callback?()
        } else {
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    private func notifyReachedEnd() {
        let callback = onReachedEnd
        if Thread.isMainThread {
            callback?()
        } else {
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    private static func duration(of data: Data, frameCount: Int) -> TimeInterval {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), frameCount > 0 else { return 0 }
        var total: TimeInterval = 0
        for index in 0..<frameCount {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                ?? gif?[kCGImagePropertyGIFDelayTime as String] as? Double
                ?? 0.1
            total += delay < 0.011 ? 0.1 : delay
        }
        return total
    }

    private static func copyImage(_ cgImage: CGImage) -> UIImage {
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return UIImage(cgImage: cgImage)
        }
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let copied = context.makeImage() else {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(cgImage: copied)
    }

    private static func gifURL(named name: String) -> URL? {
        let bundles = [Bundle.main, Bundle(for: GIFImageView.self)]
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: "gif") {
                return url
            }
        }
        return nil
    }
}
