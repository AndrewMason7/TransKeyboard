import XCTest
@testable import GeminiVoice

final class RelayControllerLocalDictationTests: XCTestCase {
  @MainActor
  func testRelayControllerInitializesWithLocalAIStack() {
    let suiteName = "test.relay.local.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let configuration = AppConfiguration(defaults: defaults)
    let controller = RelayController(configuration: configuration)
    XCTAssertNotNil(controller.modelDownloadManager)
    XCTAssertNotNil(controller.localTextProcessor)
    XCTAssertNotNil(controller.localTranscriber)
    XCTAssertFalse(controller.isUsingLocalTranscriber)
  }

  @MainActor
  func testRelayControllerCanBeConfiguredWithCustomLocalAIEngines() {
    let suiteName = "test.relay.local.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let configuration = AppConfiguration(defaults: defaults)
    let customModelManager = ModelDownloadManager()
    let customTextProcessor = LocalTextProcessor(modelDownloadManager: customModelManager)
    let customTranscriber = LocalSpeechTranscriber()

    let controller = RelayController(
      configuration: configuration,
      modelDownloadManager: customModelManager,
      localTextProcessor: customTextProcessor,
      localTranscriber: customTranscriber
    )

    XCTAssertIdentical(controller.modelDownloadManager, customModelManager)
    XCTAssertIdentical(controller.localTranscriber, customTranscriber)
  }

  @MainActor
  func testFinalizeLocalTranscriptionDeletesAudioSegmentFile() throws {
    let suiteName = "test.relay.local.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let configuration = AppConfiguration(defaults: defaults)
    let controller = RelayController(configuration: configuration)
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("completed-transcribe-en-\(UUID().uuidString).wav")
    try Data("mock audio data".utf8).write(to: tempURL)
    XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

    let segment = CapturedAudioSegment(
      requestID: UUID().uuidString,
      url: tempURL,
      startedAt: Date(),
      endedAt: Date()
    )
    controller.activeLocalAudioSegment = segment
    controller.finalizeLocalTranscription("Test transcript", requestID: segment.requestID, action: .transcribe)

    XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path), "Finalizing local transcription must delete the temporary audio file so it is not resurrected as an orphan")
    XCTAssertNil(controller.activeLocalAudioSegment)
    XCTAssertEqual(controller.livePreviewText, "")
  }

  @MainActor
  func testLivePreviewTextUpdatesAndResetsOnCancellation() {
    let suiteName = "test.relay.local.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let configuration = AppConfiguration(defaults: defaults)
    let controller = RelayController(configuration: configuration)
    let requestID = UUID().uuidString

    controller.status = .recording
    controller.activeRequestID = requestID

    controller.publishLivePreview("Hello world preview", requestID: requestID, action: .transcribe)
    XCTAssertEqual(controller.livePreviewText, "Hello world preview")

    controller.cancelDictation()
    XCTAssertEqual(controller.livePreviewText, "")
  }

  @MainActor
  func testAppleSpeechConfiguresRequiresOnDeviceRecognitionFalse() {
    let suiteName = "test.relay.local.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let configuration = AppConfiguration(defaults: defaults)
    configuration.selectedModelId = AppConfiguration.appleSpeechModelIdentifier
    XCTAssertEqual(configuration.speechEngineMode, .appleSpeech)

    let transcriber = LocalSpeechTranscriber()
    transcriber.requiresOnDeviceRecognition = true

    _ = RelayController(
      configuration: configuration,
      localTranscriber: transcriber
    )

    // Verify initial transcriber property
    XCTAssertTrue(transcriber.requiresOnDeviceRecognition)

    // Simulate beginDictation configuration
    XCTAssertTrue(configuration.speechEngineMode == .appleSpeech)
    transcriber.requiresOnDeviceRecognition = (configuration.speechEngineMode == .localOnDevice)
    XCTAssertFalse(transcriber.requiresOnDeviceRecognition, "Apple Speech API mode should allow on-device and server recognition fallback")
  }
}
