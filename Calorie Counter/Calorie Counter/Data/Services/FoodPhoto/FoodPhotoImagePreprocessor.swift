import UIKit

enum FoodPhotoImagePreprocessor {
    static func prepareJPEGBase64(
        from data: Data,
        maxDimension: CGFloat = 1280,
        compressionQuality: CGFloat = 0.72
    ) throws -> (base64: String, mimeType: String) {
        guard !data.isEmpty else { throw FoodPhotoAnalysisError.emptyImage }
        guard let image = UIImage(data: data) else {
            throw FoodPhotoAnalysisError.compressionFailed
        }
        return try prepareJPEGBase64(from: image, maxDimension: maxDimension, compressionQuality: compressionQuality)
    }

    static func prepareJPEGBase64(
        from image: UIImage,
        maxDimension: CGFloat = 1280,
        compressionQuality: CGFloat = 0.72
    ) throws -> (base64: String, mimeType: String) {
        let normalized = image.normalizedOrientation()
        let resized = normalized.resized(maxDimension: maxDimension)
        guard let jpeg = resized.jpegData(compressionQuality: compressionQuality), !jpeg.isEmpty else {
            throw FoodPhotoAnalysisError.compressionFailed
        }
        if jpeg.count > 3_500_000, let tighter = resized.jpegData(compressionQuality: 0.55) {
            return (tighter.base64EncodedString(), "image/jpeg")
        }
        return (jpeg.base64EncodedString(), "image/jpeg")
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
