import Foundation
import XCTest

@testable import GeminiVoice

@MainActor
final class FeatureFlagStoreTests: XCTestCase {
  private var testDefaults: UserDefaults!
  private var store: FeatureFlagStore!
  private let suiteName = "test.featureflags.\(UUID().uuidString)"

  override func setUp() async throws {
    try await super.setUp()
    testDefaults = UserDefaults(suiteName: suiteName)!
    testDefaults.removePersistentDomain(forName: suiteName)
    store = FeatureFlagStore(defaults: testDefaults)
  }

  override func tearDown() async throws {
    testDefaults.removePersistentDomain(forName: suiteName)
    testDefaults = nil
    store = nil
    try await super.tearDown()
  }

  func testFeatureFlagMetadataIsComplete() {
    for flag in FeatureFlag.allCases {
      XCTAssertFalse(flag.id.isEmpty)
      XCTAssertFalse(flag.title.isEmpty)
      XCTAssertFalse(flag.subtitle.isEmpty)
      XCTAssertFalse(flag.category.rawValue.isEmpty)
      XCTAssertFalse(flag.category.systemImage.isEmpty)
    }
  }

  func testFeatureFlagDefaultValues() {
    XCTAssertTrue(FeatureFlag.geminiLiveStreaming.defaultValue)
    XCTAssertTrue(FeatureFlag.geminiBatchFallback.defaultValue)
    XCTAssertTrue(FeatureFlag.onDeviceGemma.defaultValue)
    XCTAssertTrue(FeatureFlag.liveActivity.defaultValue)
    XCTAssertTrue(FeatureFlag.keyboardHandoff.defaultValue)
    XCTAssertTrue(FeatureFlag.visualOCR.defaultValue)
    XCTAssertTrue(FeatureFlag.waveformVisualizer.defaultValue)
    XCTAssertFalse(FeatureFlag.verboseDiagnostics.defaultValue)
    XCTAssertFalse(FeatureFlag.simulatedFailures.defaultValue)
  }

  func testInitialStoreReflectsDefaultValuesWithoutOverrides() {
    for flag in FeatureFlag.allCases {
      XCTAssertEqual(store.isEnabled(flag), flag.defaultValue)
      XCTAssertEqual(store[flag], flag.defaultValue)
      XCTAssertFalse(store.hasOverride(flag))
    }
  }

  func testSetEnabledCreatesOverrideAndPersists() {
    // Override a default-true flag to false
    XCTAssertTrue(store[.visualOCR])
    store[.visualOCR] = false
    XCTAssertFalse(store[.visualOCR])
    XCTAssertTrue(store.hasOverride(.visualOCR))

    // Override a default-false flag to true
    XCTAssertFalse(store[.verboseDiagnostics])
    store.setEnabled(.verboseDiagnostics, isEnabled: true)
    XCTAssertTrue(store.isEnabled(.verboseDiagnostics))
    XCTAssertTrue(store.hasOverride(.verboseDiagnostics))
  }

  func testResetOverrideRestoresDefault() {
    store[.liveActivity] = false
    XCTAssertFalse(store[.liveActivity])
    XCTAssertTrue(store.hasOverride(.liveActivity))

    store.resetOverride(.liveActivity)
    XCTAssertTrue(store[.liveActivity])
    XCTAssertFalse(store.hasOverride(.liveActivity))
  }

  func testResetToDefaultsClearsAllOverrides() {
    store[.waveformVisualizer] = false
    store[.simulatedFailures] = true
    XCTAssertTrue(store.hasOverride(.waveformVisualizer))
    XCTAssertTrue(store.hasOverride(.simulatedFailures))

    store.resetToDefaults()

    XCTAssertFalse(store.hasOverride(.waveformVisualizer))
    XCTAssertFalse(store.hasOverride(.simulatedFailures))
    XCTAssertTrue(store[.waveformVisualizer])
    XCTAssertFalse(store[.simulatedFailures])
  }
}
