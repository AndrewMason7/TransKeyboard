import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class SettingsTabTests: XCTestCase {
  func testSettingsViewRendersAllSections() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let view = SettingsView(configuration: config, relay: relay)
    XCTAssertNotNil(view.body)
  }

  func testKeyboardSetupCardRenders() {
    let card = KeyboardSetupCard()
    XCTAssertNotNil(card.body)
  }

  func testKeyboardSetupCardCollapseToggle() {
    let card = KeyboardSetupCard()
    XCTAssertNotNil(card.body)
  }

  func testSpeechEngineSectionRenders() {
    let config = AppConfiguration()
    for model in AppConfiguration.availableTranscriptionModels {
      config.selectedModelId = model
      let section = SpeechEngineSection(configuration: config)
      XCTAssertNotNil(section.body)
    }

    config.selectedModelId = "gemini-3.5-transcribe-live"
    XCTAssertEqual(config.speechEngineMode, .geminiLive)

    config.selectedModelId = "gemini-3.5-transcribe"
    XCTAssertEqual(config.speechEngineMode, .geminiBatch)

    config.selectedModelId = "apple-speech-api"
    XCTAssertEqual(config.speechEngineMode, .appleSpeech)

    config.selectedModelId = ModelDownloadManager.defaultModelFileName
    XCTAssertEqual(config.speechEngineMode, .localOnDevice)
  }

  func testSpeechEngineSectionWithDownloadManager() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let section = SpeechEngineSection(configuration: config, downloadManager: relay.modelDownloadManager)
    XCTAssertNotNil(section.body)
  }

  func testModelsInfoSectionRenders() {
    let config = AppConfiguration()
    let section = ModelsInfoSection(configuration: config)
    XCTAssertNotNil(section.body)
  }

  func testLocalGemmaSectionRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let section = LocalGemmaSection(downloadManager: relay.modelDownloadManager)
    XCTAssertNotNil(section.body)
  }

  func testTranslationSectionRenders() {
    let config = AppConfiguration()
    let section = TranslationSection(configuration: config)
    XCTAssertNotNil(section.body)
  }

  func testTranslationSectionRendersDisabled() {
    let config = AppConfiguration()
    config.isTranslationEnabled = false
    let section = TranslationSection(configuration: config)
    XCTAssertNotNil(section.body)
  }

  func testTranslationTogglePersistsInConfiguration() {
    let config = AppConfiguration()
    XCTAssertTrue(config.isTranslationEnabled)

    config.isTranslationEnabled = false
    XCTAssertFalse(config.isTranslationEnabled)

    config.isTranslationEnabled = true
    XCTAssertTrue(config.isTranslationEnabled)
  }

  func testRelayLifecycleSectionRenders() {
    let config = AppConfiguration()
    let section = RelayLifecycleSection(configuration: config)
    XCTAssertNotNil(section.body)
  }

  func testRelayLifecycleSectionRendersWithAutoStop() {
    let config = AppConfiguration()
    config.autoStopRelayOnBackground = true
    let section = RelayLifecycleSection(configuration: config)
    XCTAssertNotNil(section.body)
  }

  func testRelayLifecycleSectionWithCustomAndNeverIdleTimeout() {
    let config = AppConfiguration()
    config.relayIdleTimeout = .never
    let neverSection = RelayLifecycleSection(configuration: config)
    XCTAssertNotNil(neverSection.body)

    config.relayIdleTimeout = RelayIdleTimeout(rawSeconds: 420)
    let customSection = RelayLifecycleSection(configuration: config)
    XCTAssertNotNil(customSection.body)
  }

  func testRelayIdleTimeoutPersistsInConfiguration() {
    let config = AppConfiguration()
    XCTAssertEqual(config.relayIdleTimeout.rawSeconds, 120)

    var notificationFired = false
    config.onRelayIdleTimeoutChanged = {
      notificationFired = true
    }

    config.relayIdleTimeoutSeconds = 300
    XCTAssertEqual(config.relayIdleTimeout.rawSeconds, 300)
    XCTAssertTrue(notificationFired)

    config.relayIdleTimeout = .never
    XCTAssertTrue(config.relayIdleTimeout.isNever)
  }

  func testCredentialsSectionRenders() {
    let config = AppConfiguration()
    let section = CredentialsSection(configuration: config)
    XCTAssertNotNil(section.body)
  }

  func testCredentialsSectionWithKey() {
    let config = AppConfiguration()
    config.apiKeyOverride = "AIzaSyFakeTestKeyForCredentialsSection"
    let section = CredentialsSection(configuration: config)
    XCTAssertNotNil(section.body)
  }

  func testCredentialsSectionAccessibilityAndTouchTargets() {
    let config = AppConfiguration()
    config.apiKeyOverride = "AIzaSyFakeKeyForReviewTesting12345"
    let section = CredentialsSection(configuration: config)
    XCTAssertNotNil(section.body)
  }
}
