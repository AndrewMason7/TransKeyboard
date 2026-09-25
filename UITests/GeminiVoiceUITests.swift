import XCTest

@MainActor
final class GeminiVoiceUITests: XCTestCase {
  func testLaunchShowsRelayAndSetupInstructions() {
    let app = XCUIApplication()
    app.launchEnvironment["GEMINI_VOICE_DISABLE_RELAY_AUTOSTART"] = "1"
    app.launch()

    // Studio Tab Verification
    XCTAssertTrue(app.staticTexts["Gemini Voice"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["relay-control-button"].exists)
    XCTAssertTrue(app.buttons["camera-ocr-button"].exists)

    // Navigate to Settings Tab
    let settingsTab = app.tabBars.buttons["Settings"]
    if settingsTab.waitForExistence(timeout: 3) {
      settingsTab.tap()
    } else {
      let settingsButton = app.buttons["Settings"]
      XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
      settingsButton.tap()
    }

    // Settings Tab Verification
    XCTAssertTrue(app.staticTexts["One-time setup"].waitForExistence(timeout: 3))

    let activeModel = app.descendants(matching: .any)["active-transcription-model"]
    XCTAssertTrue(reveal(activeModel, in: app))

    let translationStatus = app.descendants(matching: .any)["translation-always-available"]
    XCTAssertTrue(reveal(translationStatus, in: app))

    let translationPicker = app.descendants(matching: .any)["translation-language-picker"]
    XCTAssertTrue(reveal(translationPicker, in: app))

    let translationModel = app.descendants(matching: .any)["active-translation-model"]
    XCTAssertTrue(reveal(translationModel, in: app))
  }

  private func reveal(
    _ element: XCUIElement,
    in app: XCUIApplication,
    maximumSwipes: Int = 5
  ) -> Bool {
    for _ in 0..<maximumSwipes {
      if element.exists && element.isHittable {
        return true
      }
      app.swipeUp()
    }
    return element.waitForExistence(timeout: 2)
  }
}
