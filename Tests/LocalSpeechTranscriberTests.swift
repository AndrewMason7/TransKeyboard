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

  func testCombinedTextPreservesSpeechAcrossPauses() {
    // 1. Initial segment when accumulated text is empty
    let initial = LocalSpeechTranscriber.combinedText(
      accumulatedText: "",
      segment: "Hello this is the first sentence."
    )
    XCTAssertEqual(initial, "Hello this is the first sentence.")

    // 2. Resuming after a pause: new segment should append naturally with a space
    let combinedAfterPause = LocalSpeechTranscriber.combinedText(
      accumulatedText: initial,
      segment: "And this is spoken after a three second break."
    )
    XCTAssertEqual(
      combinedAfterPause,
      "Hello this is the first sentence. And this is spoken after a three second break."
    )

    // 3. If new segment is an expansion of accumulated text with trailing punctuation replaced
    let punctuationContinuation = LocalSpeechTranscriber.combinedText(
      accumulatedText: "Hello world.",
      segment: "Hello world, how are you today"
    )
    XCTAssertEqual(punctuationContinuation, "Hello world, how are you today")

    // 4. Sub-word prefix collision: "I like pieces" must NOT overwrite "I like pie."
    let subwordCollision = LocalSpeechTranscriber.combinedText(
      accumulatedText: "I like pie.",
      segment: "I like pieces"
    )
    XCTAssertEqual(subwordCollision, "I like pie. I like pieces")

    // 5. Identical duplicate does not duplicate
    let duplicate = LocalSpeechTranscriber.combinedText(
      accumulatedText: "Hello world",
      segment: "Hello world"
    )
    XCTAssertEqual(duplicate, "Hello world")
  }

  func testTranscriberTimedOutErrorDescription() {
    let error = LocalSpeechTranscriberError.timedOut
    XCTAssertEqual(error.localizedDescription, "Speech recognition timed out while finalizing.")
  }

  func testTranscriberCancelIsIdempotent() {
    let transcriber = LocalSpeechTranscriber()
    transcriber.cancel()
    transcriber.cancel()
    XCTAssertFalse(transcriber.isRunning)
  }

  func testTranscriberAppendAudioDataWithVariableChunkSizesDoesNotCrash() {
    let transcriber = LocalSpeechTranscriber()
    // Appending varying sizes before or during should be safe
    let chunk1 = Data(repeating: 0x01, count: 320)
    let chunk2 = Data(repeating: 0x02, count: 640)
    transcriber.appendAudioData(chunk1)
    transcriber.appendAudioData(chunk2)
    transcriber.appendAudioData(Data())
    XCTAssertFalse(transcriber.isRunning)
  }
}
