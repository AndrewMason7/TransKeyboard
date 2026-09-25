import XCTest
@testable import GeminiVoice

final class LocalTextProcessorTests: XCTestCase {
  func testHeuristicFormatterCapitalizesFirstLetterAndTrims() async {
    let processor = LocalTextProcessor(modelDownloadManager: nil)
    let raw = "   hello world this is a test   "
    let formatted = await processor.formatTranscript(raw)
    XCTAssertEqual(formatted, "Hello world this is a test.")
  }

  func testHeuristicFormatterPreservesExistingEndingPunctuation() async {
    let processor = LocalTextProcessor(modelDownloadManager: nil)
    let raw = "what time is the meeting?"
    let formatted = await processor.formatTranscript(raw)
    XCTAssertEqual(formatted, "What time is the meeting?")
  }

  func testFallbackTranslationWhenModelNotReadyReturnsAttributedText() async {
    let processor = LocalTextProcessor(modelDownloadManager: nil)
    let raw = "Good morning"
    let translated = await processor.translateText(raw, targetLanguageCode: "es")
    XCTAssertTrue(translated.contains("Good morning"))
  }
}
