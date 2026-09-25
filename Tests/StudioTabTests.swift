import XCTest
import SwiftUI
import PhotosUI
@testable import GeminiVoice

@MainActor
final class StudioTabTests: XCTestCase {
  func testStudioViewRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    var photoItem: PhotosPickerItem? = nil
    let binding = Binding(get: { photoItem }, set: { photoItem = $0 })
    let view = StudioView(configuration: config, relay: relay, selectedPhotoItem: binding)
    XCTAssertNotNil(view.body)
  }

  func testStudioRelayCardRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let card = StudioRelayCard(configuration: config, relay: relay)
    XCTAssertNotNil(card.body)
  }

  func testStudioLiveWaveformViewRenders() {
    let waveform = StudioLiveWaveformView(audioLevel: 0.5, isLive: true)
    XCTAssertNotNil(waveform.body)
  }

  func testStudioTestPlaygroundViewRenders() {
    let config = AppConfiguration()
    let relay = RelayController(configuration: config)
    let playground = StudioTestPlaygroundView(relay: relay)
    XCTAssertNotNil(playground.body)
  }
}
