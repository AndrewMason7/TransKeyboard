import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class CommonComponentsTests: XCTestCase {
  func testStatusPillRenders() {
    let pill = StatusPillView(status: .idle)
    XCTAssertNotNil(pill.body)
  }

  func testKeyboardHandoffOverlayRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let overlay = KeyboardHandoffOverlay(relay: relay)
    XCTAssertNotNil(overlay.body)
  }

  func testKeyboardHandoffOverlayReturnButtonWithKnownHost() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    relay.pendingLaunchRequest = RelayLaunchRequest(
      requestID: UUID().uuidString,
      dictationAction: .transcribe,
      createdAt: Date(),
      originatingApplicationBundleIdentifier: "com.apple.mobilenotes"
    )
    relay.requiresManualKeyboardReturn = true
    XCTAssertEqual(relay.hostApplicationDisplayName, "Notes")
    let overlay = KeyboardHandoffOverlay(relay: relay)
    XCTAssertNotNil(overlay.body)

    relay.returnToHostApplication()
    XCTAssertFalse(relay.isKeyboardHandoffActive)
    XCTAssertFalse(relay.requiresManualKeyboardReturn)
  }
}
