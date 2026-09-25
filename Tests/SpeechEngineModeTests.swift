import XCTest
@testable import GeminiVoice

final class SpeechEngineModeTests: XCTestCase {
  func testDefaultSpeechEngineModeIsGeminiLive() {
    let mode = SpeechEngineMode.defaultMode
    XCTAssertEqual(mode, .geminiLive)
  }

  func testSpeechEngineModeDisplayTitles() {
    XCTAssertEqual(SpeechEngineMode.geminiLive.displayName, "Gemini Live (Cloud)")
    XCTAssertEqual(SpeechEngineMode.localOnDevice.displayName, "Local On-Device")
    XCTAssertEqual(SpeechEngineMode.autoFallback.displayName, "Gemini Live with Fallback")
  }

  @MainActor
  func testConfigurationPersistsSpeechEngineMode() {
    let suiteName = "test.speechengine.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create isolated defaults")
      return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let config = AppConfiguration(defaults: defaults)
    XCTAssertEqual(config.speechEngineMode, .geminiLive)

    config.speechEngineMode = .localOnDevice
    XCTAssertEqual(config.speechEngineMode, .localOnDevice)

    let reloadedConfig = AppConfiguration(defaults: defaults)
    XCTAssertEqual(reloadedConfig.speechEngineMode, .localOnDevice)
  }

  @MainActor
  func testConfigurationPersistsLiveTranscriptionModel() {
    let suiteName = "test.livemodel.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create isolated defaults")
      return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let config = AppConfiguration(defaults: defaults)
    XCTAssertEqual(config.liveTranscriptionModel, GeminiLiveSpeechSession.defaultTranscriptionModel)

    config.liveTranscriptionModel = "gemini-3.1-flash-live-preview"
    XCTAssertEqual(config.liveTranscriptionModel, "gemini-3.1-flash-live-preview")

    let reloadedConfig = AppConfiguration(defaults: defaults)
    XCTAssertEqual(reloadedConfig.liveTranscriptionModel, "gemini-3.1-flash-live-preview")
  }

  @MainActor
  func testActiveTranscriptionModelDisplayReflectsEngineAndModel() {
    let suiteName = "test.activemodel.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create isolated defaults")
      return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let config = AppConfiguration(defaults: defaults)

    config.selectedModelId = "gemini-3.5-transcribe-live"
    XCTAssertEqual(config.speechEngineMode, .geminiLive)
    XCTAssertEqual(config.activeTranscriptionModelDisplay, "gemini-3.5-transcribe-live")

    config.selectedModelId = "gemini-3.5-transcribe"
    XCTAssertEqual(config.speechEngineMode, .geminiBatch)
    XCTAssertEqual(config.activeTranscriptionModelDisplay, "gemini-3.5-transcribe")

    config.selectedModelId = ModelDownloadManager.defaultModelFileName
    XCTAssertEqual(config.speechEngineMode, .localOnDevice)
    XCTAssertEqual(config.activeTranscriptionModelDisplay, ModelDownloadManager.defaultModelFileName)

    config.speechEngineMode = .autoFallback
    XCTAssertEqual(config.activeTranscriptionModelDisplay, "gemini-3.5-transcribe-live")
  }

  func testSpeechEngineModeHelpersForRawModelIdentifiers() {
    XCTAssertEqual(SpeechEngineMode.mode(for: "gemini-3.5-transcribe-live"), .geminiLive)
    XCTAssertEqual(SpeechEngineMode.mode(for: "gemini-3.5-transcribe"), .geminiBatch)
    XCTAssertEqual(SpeechEngineMode.mode(for: "gemma-4-E2B-it.litert-lm"), .localOnDevice)
    XCTAssertEqual(SpeechEngineMode.iconName(for: "gemini-3.5-transcribe-live"), "bolt.badge.automatic.fill")
    XCTAssertEqual(SpeechEngineMode.iconName(for: "gemini-3.5-transcribe"), "cloud.fill")
    XCTAssertEqual(SpeechEngineMode.iconName(for: "gemma-4-E2B-it.litert-lm"), "lock.shield.fill")
  }

  func testGeminiLiveModelPresets() {
    let models = GeminiLiveModel.allAvailable
    XCTAssertEqual(models.count, 3)
    XCTAssertTrue(models.contains(where: { $0.id == "gemini-3.5-transcribe-live" }))
    XCTAssertTrue(models.contains(where: { $0.id == "gemini-3.5-transcribe" }))
    XCTAssertTrue(models.contains(where: { $0.id == ModelDownloadManager.defaultModelFileName }))
    XCTAssertEqual(GeminiLiveModel.displayName(for: "gemini-3.5-transcribe-live"), "gemini-3.5-transcribe-live")
    XCTAssertEqual(GeminiLiveModel.displayName(for: "gemini-3.5-transcribe"), "gemini-3.5-transcribe")
    XCTAssertEqual(GeminiLiveModel.displayName(for: ModelDownloadManager.defaultModelFileName), ModelDownloadManager.defaultModelFileName)
  }

  func testSpeechEngineModeTelemetryMetadata() {
    for mode in SpeechEngineMode.allCases {
      XCTAssertFalse(mode.iconName.isEmpty, "Icon must not be empty for \(mode)")
      XCTAssertFalse(mode.badgeText.isEmpty, "Badge must not be empty for \(mode)")
      XCTAssertFalse(mode.latencyEstimate.isEmpty, "Latency must not be empty for \(mode)")
      XCTAssertFalse(mode.featureHighlights.isEmpty, "Highlights must not be empty for \(mode)")
    }

    XCTAssertEqual(SpeechEngineMode.geminiLive.iconName, "bolt.badge.automatic.fill")
    XCTAssertEqual(SpeechEngineMode.geminiLive.badgeText, "RECOMMENDED")
    XCTAssertEqual(SpeechEngineMode.localOnDevice.badgeText, "100% PRIVATE")
    XCTAssertEqual(SpeechEngineMode.autoFallback.badgeText, "SMART HYBRID")
  }

  @MainActor
  func testSpeechEngineModeSynchronizesToSharedDefaults() {
    let suiteName = "test.sharedsync.\(UUID().uuidString)"
    let sharedSuiteName = "test.sharedsync.group.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName),
          let sharedDefaults = UserDefaults(suiteName: sharedSuiteName) else {
      XCTFail("Failed to create isolated defaults")
      return
    }
    defer {
      defaults.removePersistentDomain(forName: suiteName)
      sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
    }

    let config = AppConfiguration(defaults: defaults, sharedDefaults: sharedDefaults)
    config.speechEngineMode = .localOnDevice

    XCTAssertEqual(sharedDefaults.string(forKey: AppConfiguration.Key.speechEngineMode), SpeechEngineMode.localOnDevice.rawValue)
  }

  @MainActor
  func testActiveModelIdentifierSynchronizesToSharedDefaults() {
    let suiteName = "test.modelid.\(UUID().uuidString)"
    let sharedSuiteName = "test.modelid.group.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName),
          let sharedDefaults = UserDefaults(suiteName: sharedSuiteName) else {
      XCTFail("Failed to create isolated defaults")
      return
    }
    defer {
      defaults.removePersistentDomain(forName: suiteName)
      sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
    }

    let config = AppConfiguration(defaults: defaults, sharedDefaults: sharedDefaults)
    XCTAssertEqual(sharedDefaults.string(forKey: AppConfiguration.Key.activeModelIdentifier), "gemini-3.5-transcribe-live")

    config.selectedModelId = "gemma-4-E2B-it.litert-lm"
    XCTAssertEqual(config.selectedModelId, "gemma-4-E2B-it.litert-lm")
    XCTAssertEqual(config.speechEngineMode, .localOnDevice)
    XCTAssertEqual(sharedDefaults.string(forKey: AppConfiguration.Key.activeModelIdentifier), "gemma-4-E2B-it.litert-lm")
    XCTAssertEqual(sharedDefaults.string(forKey: AppConfiguration.Key.speechEngineMode), SpeechEngineMode.localOnDevice.rawValue)
  }
}
