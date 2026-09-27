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

  func testTranscriberIgnoresAudioWhenNotRunning() {
    let transcriber = LocalSpeechTranscriber()
    // Appending audio before start should not crash or change state
    transcriber.appendAudioData(Data([0x00, 0x01]))
    XCTAssertFalse(transcriber.isRunning)
  }

  func testTranscriberPCMFormatIs16kHzMono() {
    let format = LocalSpeechTranscriber.pcm16Format
    XCTAssertNotNil(format)
    XCTAssertEqual(format?.sampleRate, 16000)
    XCTAssertEqual(format?.channelCount, 1)
  }

  func testTranscriberThrowsTypedErrorWhenUnavailable() {
    let unavailableTranscriber = LocalSpeechTranscriber(locale: Locale(identifier: "xx-ZZ"))
    XCTAssertThrowsError(try unavailableTranscriber.start(progressHandler: { _ in }, completionHandler: { _ in })) { error in
      guard let transcriberError = error as? LocalSpeechTranscriberError else {
        return XCTFail("Expected LocalSpeechTranscriberError but got \(error)")
      }
      XCTAssertEqual(transcriberError, .recognizerUnavailable)
      XCTAssertFalse(transcriberError.localizedDescription.isEmpty)
    }
  }
}
