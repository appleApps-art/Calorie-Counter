import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Photos the user takes are kept at a size a phone screen can show, not at camera resolution,
/// and are always decoded straight to the size they are drawn at.
///
/// A 12-megapixel camera photo is 3–5 MB on disk and a ~48 MB bitmap once decoded; a list
/// thumbnail built from it holds all of that in memory.
enum StoredPhoto {
    static let maxDimension = 1600
    static let quality: CGFloat = 0.8

    /// Re-encodes a photo that is larger than `maxDimension` on its longest side. Anything already
    /// that small is returned untouched, so saving the same entry again never re-compresses it.
    static func compacted(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return data }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let longest = longestSide(of: source), longest > CGFloat(maxDimension),
              let image = thumbnail(from: source, maxPixelSize: maxDimension),
              let encoded = jpegData(image, quality: quality),
              encoded.count < data.count else { return data }
        return encoded
    }

    static func image(from data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = thumbnail(from: source, maxPixelSize: maxPixelSize) else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    static func image(contentsOf url: URL, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = thumbnail(from: source, maxPixelSize: maxPixelSize) else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    /// The pixel size to decode for a view, given how large it is drawn on screen.
    static func pixelSize(forPoints points: CGFloat, scale: CGFloat = 3) -> Int {
        max(1, Int((max(points, 1) * max(scale, 1)).rounded(.up)))
    }

    private static func longestSide(of source: CGImageSource) -> CGFloat? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return max(width, height)
    }

    private static func thumbnail(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            // Bakes in the EXIF orientation, so the result is always upright.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1)
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private static func jpegData(_ image: CGImage, quality: CGFloat) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
