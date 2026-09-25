import AVFoundation
import XCTest

@testable import GeminiVoice

final class AudioCaptureEngineTests: XCTestCase {
  func testRejectsStaleRouteFormatBeforeInstallingTap() throws {
    let oldRoute = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
    let newRoute = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
    let stereoRoute = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
    XCTAssertFalse(AudioCaptureEngine.isUsableInputFormat(oldRoute, hardwareFormat: newRoute))
    XCTAssertFalse(AudioCaptureEngine.isUsableInputFormat(newRoute, hardwareFormat: stereoRoute))
    XCTAssertTrue(AudioCaptureEngine.isUsableInputFormat(newRoute, hardwareFormat: newRoute))
  }

  @MainActor
  func testReplacedEngineIgnoresOldConfigurationNotifications() {
    let capture = AudioCaptureEngine()
    let oldEngine = capture.engine
    capture.replaceStoppedEngine()
    XCTAssertFalse(oldEngine === capture.engine)
    capture.shouldBeRunning = true
    NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: oldEngine)
    XCTAssertNil(capture.recoveryWorkItem)
    NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: capture.engine)
    XCTAssertNotNil(capture.recoveryWorkItem)
    capture.stop()
    XCTAssertNil(capture.recoveryWorkItem)
  }

  func testRecoverableRecordingScanRunsOnlyOncePerRelayInstance() {
    var gate = RecoverableRecordingScanGate()

    XCTAssertTrue(gate.claim())
    XCTAssertFalse(gate.claim(), "Route recovery must not rescan a finalized recovery WAV")
  }

  func testSimulatorReportsMicrophoneCaptureAsUnavailableWithoutStartingAudioIO() {
    #if targetEnvironment(simulator)
      XCTAssertFalse(AudioCaptureEngine.isMicrophoneCaptureAvailable)
      XCTAssertThrowsError(try AudioCaptureEngine().start()) { error in
        guard case AudioCaptureError.simulatorMicrophoneUnavailable = error else {
          return XCTFail("Unexpected error: \(error)")
        }
      }
    #else
      XCTAssertTrue(AudioCaptureEngine.isMicrophoneCaptureAvailable)
    #endif
  }

  func testPCMChunkerProducesRouteIndependentHundredMillisecondPackets() {
    var chunker = PCM16StreamChunker()
    let first = chunker.append(Data(repeating: 0x11, count: 1_100))
    let second = chunker.append(Data(repeating: 0x22, count: 5_500))

    XCTAssertTrue(first.isEmpty)
    XCTAssertEqual(second.map(\.count), [3_200, 3_200])
    XCTAssertEqual(chunker.bufferedData.count, 200)
    XCTAssertEqual(chunker.finish()?.count, 200)
    XCTAssertTrue(chunker.bufferedData.isEmpty)
  }

  func testPCMChunkerResetDiscardsCancelledSegmentTail() {
    var chunker = PCM16StreamChunker()
    XCTAssertTrue(chunker.append(Data(repeating: 0x33, count: 900)).isEmpty)
    chunker.reset()
    XCTAssertNil(chunker.finish())
  }

  func testCopyBufferProducesIndependentDeepCopy() throws {
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100))
    buffer.frameLength = 100
    let channelData = try XCTUnwrap(buffer.floatChannelData)
    channelData[0][0] = 0.42
    channelData[0][99] = 0.99

    let copy = try XCTUnwrap(buffer.copyBuffer())
    XCTAssertEqual(copy.frameLength, 100)
    let copyData = try XCTUnwrap(copy.floatChannelData)
    XCTAssertEqual(copyData[0][0], 0.42, accuracy: 0.0001)
    XCTAssertEqual(copyData[0][99], 0.99, accuracy: 0.0001)

    // Mutating original buffer must not affect copy
    channelData[0][0] = 0.0
    channelData[0][99] = 0.0
    XCTAssertEqual(copyData[0][0], 0.42, accuracy: 0.0001)
    XCTAssertEqual(copyData[0][99], 0.99, accuracy: 0.0001)
  }

  func testCopyBufferMultiChannelNonInterleaved() throws {
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
    buffer.frameLength = 64
    let channelData = try XCTUnwrap(buffer.floatChannelData)
    channelData[0][0] = 0.123
    channelData[1][0] = 0.789

    let copy = try XCTUnwrap(buffer.copyBuffer())
    XCTAssertEqual(copy.frameLength, 64)
    let copyData = try XCTUnwrap(copy.floatChannelData)
    XCTAssertEqual(copyData[0][0], 0.123, accuracy: 0.0001)
    XCTAssertEqual(copyData[1][0], 0.789, accuracy: 0.0001)

    // Mutation test on channel 1
    channelData[1][0] = -0.5
    XCTAssertEqual(copyData[1][0], 0.789, accuracy: 0.0001)
  }

  func testCopyBufferInterleavedFormatDoesNotCrashAndPreservesSamples() throws {
    let format = try XCTUnwrap(
      AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 2, interleaved: true)
    )
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32))
    buffer.frameLength = 32
    let channelData = try XCTUnwrap(buffer.floatChannelData)
    // In interleaved float32 with 2 channels, 32 frames = 64 floats stored consecutively in channelData[0]
    channelData[0][0] = 0.25
    channelData[0][1] = 0.75
    channelData[0][62] = 0.33
    channelData[0][63] = 0.66

    let copy = try XCTUnwrap(buffer.copyBuffer())
    XCTAssertEqual(copy.frameLength, 32)
    let copyData = try XCTUnwrap(copy.floatChannelData)
    XCTAssertEqual(copyData[0][0], 0.25, accuracy: 0.0001)
    XCTAssertEqual(copyData[0][1], 0.75, accuracy: 0.0001)
    XCTAssertEqual(copyData[0][62], 0.33, accuracy: 0.0001)
    XCTAssertEqual(copyData[0][63], 0.66, accuracy: 0.0001)
  }
}

private actor LiveActivityOperationRecorder {
  private var events: [String] = []

  func append(_ event: String) {
    events.append(event)
  }

  func snapshot() -> [String] {
    events
  }
}

final class VoiceRelayLiveActivityOperationQueueTests: XCTestCase {
  @MainActor
  func testEndCompletesBeforeReplacementStartRuns() async {
    let queue = VoiceRelayLiveActivityOperationQueue()
    let recorder = LiveActivityOperationRecorder()

    queue.enqueue {
      await recorder.append("end started")
      try? await Task.sleep(nanoseconds: 20_000_000)
      await recorder.append("end finished")
    }
    queue.enqueue {
      await recorder.append("replacement started")
    }

    await queue.waitUntilIdle()
    let events = await recorder.snapshot()
    XCTAssertEqual(
      events,
      ["end started", "end finished", "replacement started"]
    )
  }

  @MainActor
  func testQueueDrainsToIdleAndAcceptsSubsequentWork() async {
    let queue = VoiceRelayLiveActivityOperationQueue()
    var counter = 0

    queue.enqueue {
      counter += 1
    }
    await queue.waitUntilIdle()
    XCTAssertEqual(counter, 1)

    // After draining to idle, new operations execute correctly and drain again
    queue.enqueue {
      counter += 10
    }
    await queue.waitUntilIdle()
    XCTAssertEqual(counter, 11)
  }

  @MainActor
  func testWaitUntilIdleAwaitsConcurrentlyEnqueuedWork() async {
    let queue = VoiceRelayLiveActivityOperationQueue()
    var executedOperations: [Int] = []

    queue.enqueue {
      try? await Task.sleep(nanoseconds: 20_000_000)
      executedOperations.append(1)
      // Enqueue while operation 1 is running
      queue.enqueue {
        executedOperations.append(2)
      }
    }

    await queue.waitUntilIdle()
    XCTAssertEqual(executedOperations, [1, 2])
  }
}
