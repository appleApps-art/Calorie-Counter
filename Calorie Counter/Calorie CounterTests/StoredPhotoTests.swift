import UIKit
import XCTest
@testable import Calorie_Counter

final class StoredPhotoTests: XCTestCase {
    func testACameraSizedPhotoIsStoredAtScreenSize() throws {
        let original = try XCTUnwrap(photo(width: 4032, height: 3024).jpegData(compressionQuality: 0.9))
        let stored = try XCTUnwrap(StoredPhoto.compacted(original))

        let size = try pixelSize(of: stored)
        XCTAssertEqual(max(size.width, size.height), CGFloat(StoredPhoto.maxDimension), accuracy: 1)
        XCTAssertEqual(size.width / size.height, 4032.0 / 3024.0, accuracy: 0.01, "The aspect ratio is kept")
        XCTAssertLessThan(stored.count, original.count)
    }

    func testASmallPhotoIsStoredUntouchedAndSavingAgainNeverRecompresses() throws {
        let small = try XCTUnwrap(photo(width: 800, height: 600).jpegData(compressionQuality: 0.9))
        XCTAssertEqual(StoredPhoto.compacted(small), small)

        let big = try XCTUnwrap(photo(width: 4032, height: 3024).jpegData(compressionQuality: 0.9))
        let once = StoredPhoto.compacted(big)
        XCTAssertEqual(StoredPhoto.compacted(once), once, "A second save must not lose quality again")
        XCTAssertNil(StoredPhoto.compacted(nil))
    }

    func testDecodingForAViewNeverBuildsTheFullBitmap() throws {
        let data = try XCTUnwrap(photo(width: 4032, height: 3024).jpegData(compressionQuality: 0.9))
        let thumbnail = try XCTUnwrap(StoredPhoto.image(from: data, maxPixelSize: 320))
        XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height) * thumbnail.scale, 320)
    }

    func testAFoodEntryPhotoIsCompactedWhenSaved() throws {
        let harness = TestHarness()
        let original = try XCTUnwrap(photo(width: 4032, height: 3024).jpegData(compressionQuality: 0.9))
        let entry = FoodEntry(
            id: UUID(), name: "Омлет", mealType: .breakfast,
            calories: 200, protein: 12, carbs: 2, fats: 15, fiber: 0, sugar: 0, sodium: 0,
            date: Date(), imageData: original
        )
        try harness.food.save(entry)

        let saved = try XCTUnwrap(harness.food.fetchEntries(for: entry.date).first?.imageData)
        let size = try pixelSize(of: saved)
        XCTAssertLessThanOrEqual(max(size.width, size.height), CGFloat(StoredPhoto.maxDimension))
        XCTAssertLessThan(saved.count, original.count)
    }

    func testAListRowDecodesAStoredPhotoAtItsOwnSize() throws {
        let data = try XCTUnwrap(photo(width: 4032, height: 3024).jpegData(compressionQuality: 0.9))
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        RemoteImageLoader().display(nil, data: data, in: imageView, placeholder: nil)

        let image = try XCTUnwrap(imageView.image)
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height) * image.scale, 400,
                                 "A 44 pt row must not hold a 4032 px bitmap")
    }

    // MARK: - Helpers

    private func photo(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.orange.setFill()
            context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        }
    }

    private func pixelSize(of data: Data) throws -> CGSize {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? CGFloat)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? CGFloat)
        return CGSize(width: width, height: height)
    }
}
