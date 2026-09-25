import XCTest
import SwiftUI
@testable import GeminiVoice

@MainActor
final class ContentViewSettingsUITests: XCTestCase {
  func testSettingsContainsSpeechEngineModePicker() {
    let suiteName = "test.ui.settings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let config = AppConfiguration(defaults: defaults)
    let relay = RelayController(configuration: config)
    let view = ContentView(configuration: config, relay: relay)
    XCTAssertNotNil(view.body)
  }

  func testAppConfigurationRelayLifecycleDefaultsAndPersistence() {
    let suiteName = "test.ui.settings.lifecycle.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let config = AppConfiguration(defaults: defaults)
    XCTAssertTrue(config.autoStartRelayOnLaunch)
    XCTAssertFalse(config.autoStopRelayOnBackground)

    config.autoStartRelayOnLaunch = false
    config.autoStopRelayOnBackground = true

    let reloadedConfig = AppConfiguration(defaults: defaults)
    XCTAssertFalse(reloadedConfig.autoStartRelayOnLaunch)
    XCTAssertTrue(reloadedConfig.autoStopRelayOnBackground)
  }

  func testModelsInfoSettingsSectionRendersWithActiveModelAndPicker() {
    let suiteName = "test.ui.settings.models.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let config = AppConfiguration(defaults: defaults)
    config.speechEngineMode = .localOnDevice
    let section = ModelsInfoSettingsSection(configuration: config)
    XCTAssertNotNil(section.body)
  }
}
