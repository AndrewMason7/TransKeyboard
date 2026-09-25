import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class HistoryTabTests: XCTestCase {
  func testHistoryViewRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    var pendingDeletion: RecoverableRecording? = nil
    let binding = Binding(get: { pendingDeletion }, set: { pendingDeletion = $0 })
    let view = HistoryView(relay: relay, recordingPendingDeletion: binding)
    XCTAssertNotNil(view.body)
  }

  func testTranscriptRowViewRenders() {
    let item = TranscriptHistoryItem(text: "Hello world testing dictation", createdAt: Date())
    let row = TranscriptRowView(item: item, onDelete: {})
    XCTAssertNotNil(row.body)
  }

  func testRecoverableRecordingCardRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let recording = RecoverableRecording(
      id: UUID(),
      requestID: "req-1",
      fileName: "test.m4a",
      action: .transcribe,
      translationTargetCode: "en",
      createdAt: Date(),
      duration: 5.0,
      lastError: "Connection timed out",
      retryCount: 0
    )
    let card = RecoverableRecordingCard(
      recording: recording,
      relay: relay,
      onDeleteRequest: { _ in }
    )
    XCTAssertNotNil(card.body)
  }
}
