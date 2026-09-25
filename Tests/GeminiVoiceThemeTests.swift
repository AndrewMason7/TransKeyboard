import XCTest
import SwiftUI
@testable import GeminiVoice

final class GeminiVoiceThemeTests: XCTestCase {
  func testPrimaryGradientExistsAndHasFiveStops() {
    let gradient = LinearGradient.geminiVoicePrimary
    XCTAssertNotNil(gradient)
    XCTAssertEqual(GeminiVoiceTheme.primaryGradientStops.count, 5)
  }

  func testStatusColorsCoverAllRelayStates() {
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .idle), "READY")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .recording), "LISTENING")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .transcribing), "TRANSCRIBING")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .offline), "OFFLINE")
    XCTAssertEqual(GeminiVoiceTheme.statusTitle(for: .error), "CHECK SETUP")

    XCTAssertEqual(GeminiVoiceTheme.statusColor(for: .idle), .green)
    XCTAssertEqual(GeminiVoiceTheme.statusColor(for: .recording), .red)
    XCTAssertEqual(GeminiVoiceTheme.statusColor(for: .transcribing), .cyan)
    XCTAssertEqual(GeminiVoiceTheme.statusColor(for: .offline), .gray)
    XCTAssertEqual(GeminiVoiceTheme.statusColor(for: .error), .orange)
  }

  func testAccentAndTranslationColorsAreDefined() {
    XCTAssertNotNil(GeminiVoiceTheme.accentUIColor)
    XCTAssertNotNil(GeminiVoiceTheme.translationAccent)
    XCTAssertNotNil(GeminiVoiceTheme.translationUIAccent)
  }
}
