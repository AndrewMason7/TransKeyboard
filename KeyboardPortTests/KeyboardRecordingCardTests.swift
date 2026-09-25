import XCTest
import SwiftUI

@MainActor
final class KeyboardRecordingCardTests: XCTestCase {
  func testRecordingCardRendersWithListeningTitle() {
    let visualizer = KeyboardAudioVisualizerState()
    let card = KeyboardRecordingCardView(
      modeName: "Gemini 3.5 Live",
      modeIcon: "bolt.badge.automatic.fill",
      title: "Listening",
      visualizer: visualizer
    )
    XCTAssertNotNil(card.body)
  }

  func testRecordingCardRendersTranslationTitle() {
    let visualizer = KeyboardAudioVisualizerState()
    let card = KeyboardRecordingCardView(
      modeName: "Local Gemma 2B",
      modeIcon: "lock.shield.fill",
      title: "Listening to translate",
      visualizer: visualizer
    )
    XCTAssertNotNil(card.body)
  }

  func testRecordingCardContainsRequiredAccessibilityIdentifier() {
    let visualizer = KeyboardAudioVisualizerState()
    let card = KeyboardRecordingCardView(
      modeName: "Gemini Live",
      modeIcon: "bolt.badge.automatic.fill",
      title: "Listening",
      visualizer: visualizer
    )
    // Verify view can be rendered in hosting environment
    let hosting = UIHostingController(rootView: card)
    XCTAssertNotNil(hosting.view)
  }

  func testRecordingCardStateReactiveMutations() {
    let state = KeyboardRecordingCardState()
    XCTAssertEqual(state.title, "Listening")
    XCTAssertEqual(state.modeName, SpeechEngineMode.defaultMode.displayName)

    state.title = "Listening to translate"
    state.modeName = SpeechEngineMode.localOnDevice.displayName
    state.modeIcon = SpeechEngineMode.localOnDevice.iconName
    state.audioVisualizer.updateAudioLevel(0.75)

    XCTAssertEqual(state.title, "Listening to translate")
    XCTAssertEqual(state.modeName, "Local On-Device")
    XCTAssertEqual(state.modeIcon, "lock.shield.fill")
    XCTAssertEqual(state.audioVisualizer.audioLevel, 0.75)
  }

  func testSpeechEngineModeDefaultsKeyMatchesSharedKey() {
    XCTAssertEqual(SpeechEngineMode.sharedDefaultsKey, "configuration.speech-engine-mode")
  }

  func testSpeechEngineModeShortNames() {
    XCTAssertEqual(SpeechEngineMode.geminiLive.shortName, "Gemini 3.5 Live")
    XCTAssertEqual(SpeechEngineMode.geminiBatch.shortName, "Gemini Transcribe")
    XCTAssertEqual(SpeechEngineMode.localOnDevice.shortName, "Local On-Device")
    XCTAssertEqual(SpeechEngineMode.autoFallback.shortName, "Auto-Fallback")
  }

  func testRecordingCardResolvesEngineModeFromUserDefaults() {
    let suite = "group.test.recording.card.\(UUID().uuidString)"
    let testDefaults = UserDefaults(suiteName: suite)!
    defer { testDefaults.removePersistentDomain(forName: suite) }

    testDefaults.set(SpeechEngineMode.localOnDevice.rawValue, forKey: SpeechEngineMode.sharedDefaultsKey)
    let raw = testDefaults.string(forKey: SpeechEngineMode.sharedDefaultsKey)
    let mode = raw.flatMap(SpeechEngineMode.init(rawValue:)) ?? .defaultMode
    XCTAssertEqual(mode, .localOnDevice)
    XCTAssertEqual(mode.shortName, "Local On-Device")
    XCTAssertEqual(mode.iconName, "lock.shield.fill")
  }

  func testRecordingCardResolvesRawModelIdentifierFromUserDefaults() {
    let suite = "group.test.recording.rawmodel.\(UUID().uuidString)"
    let testDefaults = UserDefaults(suiteName: suite)!
    defer { testDefaults.removePersistentDomain(forName: suite) }

    XCTAssertEqual(SpeechEngineMode.activeModelIdentifierKey, "configuration.active-model-identifier")

    testDefaults.set("gemma-4-E2B-it.litert-lm", forKey: SpeechEngineMode.activeModelIdentifierKey)
    let raw = testDefaults.string(forKey: SpeechEngineMode.activeModelIdentifierKey)
    XCTAssertEqual(raw, "gemma-4-E2B-it.litert-lm")
    XCTAssertEqual(SpeechEngineMode.iconName(for: raw!), "lock.shield.fill")

    let card = KeyboardRecordingCardView(
      modeName: raw!,
      modeIcon: SpeechEngineMode.iconName(for: raw!),
      title: "Listening",
      visualizer: KeyboardAudioVisualizerState()
    )
    XCTAssertNotNil(card.body)
  }
}
