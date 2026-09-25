import XCTest
import AVFoundation
@testable import GeminiVoice

@MainActor
final class LocalSpeechTranscriberTests: XCTestCase {
  func testTranscriberReportsAvailabilityState() {
    let transcriber = LocalSpeechTranscriber()
    let available = transcriber.isOnDeviceRecognitionAvailable
    // On-device availability depends on system locale, but property must be accessible
    _ = available
  }

  func testTranscriberCanCancelBeforeStartingWithoutThrowing() {
    let transcriber = LocalSpeechTranscriber()
    transcriber.cancel()
    let isRunning = transcriber.isRunning
    XCTAssertFalse(isRunning)
  }
}
