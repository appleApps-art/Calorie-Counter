import XCTest
@testable import Calorie_Counter

final class NativeLoaderTests: XCTestCase {
    func testLoadingOverlayShowsANativeSpinner() throws {
        let overlay = CustomLoadingOverlayView()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        overlay.attach(to: host)
        host.layoutIfNeeded()

        let spinner = try XCTUnwrap(
            overlay.subviews
                .flatMap { [$0] + $0.subviews }
                .compactMap { $0 as? UIActivityIndicatorView }
                .first
        )
        XCTAssertEqual(spinner.style, .medium)
        XCTAssertFalse(spinner.isAnimating)

        overlay.setVisible(true)
        XCTAssertTrue(spinner.isAnimating)
        XCTAssertFalse(overlay.isHidden)

        let light = spinner.color?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = spinner.color?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertNotEqual(light, dark, "The spinner must follow the theme")
    }

    func testTheSpinningLoaderIsNoLongerDrawnByLottie() throws {
        // The branded mascot loader (Loading2.gif) and the splash animation stay as they are;
        // only the round spinner became a native UIActivityIndicatorView.
        let sources = FileManager.default.enumerator(at: appSourceURL(), includingPropertiesForKeys: nil)
        var offenders: [String] = []
        while let url = sources?.nextObject() as? URL {
            guard ["xib", "storyboard", "swift"].contains(url.pathExtension) else { continue }
            if url.lastPathComponent.hasPrefix("SplashViewController") { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("LottieAnimationView") || text.contains("CustomLoadingTransparent") {
                offenders.append(url.lastPathComponent)
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "The round Lottie spinner is still used here")
    }

    func testSpinnersStayAtTheSmallerSize() throws {
        let sources = FileManager.default.enumerator(at: appSourceURL(), includingPropertiesForKeys: nil)
        var offenders: [String] = []
        while let url = sources?.nextObject() as? URL {
            guard ["xib", "storyboard", "swift"].contains(url.pathExtension) else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            let large = text.contains("UIActivityIndicatorView(style: .large)")
                || text.components(separatedBy: "activityIndicatorView").dropFirst().contains {
                    $0.prefix(400).contains("style=\"large\"")
                }
            if large { offenders.append(url.lastPathComponent) }
        }
        XCTAssertEqual(offenders.sorted(), [], "Spinners must use the medium size")
    }

    private func appSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter")
    }
}
