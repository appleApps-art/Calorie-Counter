import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class VoiceLogScreenTests: XCTestCase {
    func testClearingAConfirmedTranscriptBringsTheMicrophoneBack() throws {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
        let chrome = VoiceMicButtonChrome()
        chrome.attach(button)

        // After speaking the button turns into the teal confirm checkmark.
        chrome.apply(isRecording: false, canConfirm: true)
        XCTAssertNotNil(button.image(for: .normal))

        // The clear button resets the screen to idle, which styles the microphone again.
        OnboardingStyle.styleGlassSymbolButton(button, systemName: "microphone.fill", foregroundColor: .black)

        XCTAssertNil(button.image(for: .normal), "A leftover checkmark would be drawn over the microphone")
        XCTAssertNotNil(button.configuration?.image)
        XCTAssertEqual(button.backgroundColor, .clear, "No teal confirm fill behind the microphone either")
    }

    func testTheScreenUsesTheVoiceBackgroundArtwork() throws {
        XCTAssertNotNil(UIImage(named: "voiceBackground"))
        let xib = try String(contentsOf: sourceURL("Features/FoodLogging/VoiceLogViewController.xib"), encoding: .utf8)
        XCTAssertTrue(xib.contains("image=\"voiceBackground\""))
        XCTAssertFalse(xib.contains("VoiceLogDecorationsView"), "The hand-placed outlines are replaced by the artwork")
    }

    private func sourceURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter")
            .appendingPathComponent(path)
    }
}
