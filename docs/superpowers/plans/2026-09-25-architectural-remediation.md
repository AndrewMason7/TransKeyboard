# Architectural & Memory Safety Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remediate critical CoreAudio buffer memory safety vulnerabilities, eliminate trailing garbage memory in live streaming, resolve local AI dictation WAV disk and recovery state leaks, fix background task retain cycles, and harden IPC locking against main-thread watchdog timeouts.

**Architecture:** 
1. Replace flawed manual pointer math in `AVAudioPCMBuffer.copyBuffer()` with format-aware `AudioBufferList` copying that supports both interleaved and non-interleaved formats safely.
2. Clamp streaming PCM chunk byte counts to actual `frameLength * bytesPerFrame` instead of buffer allocation capacity.
3. Track and purge completed local transcription audio segments upon successful insertion, staging fallback only on failure.
4. Add `[weak self]` to background task expiration closures and throttle audio metering IPC flushes.

**Tech Stack:** Swift 6.2, AVFoundation/CoreAudio, AudioToolbox, SpeechKit, ActivityKit, XCTest, MobileBuildMCP.

**Review Artifact:** [`architectural-and-code-review.md`](architectural-and-code-review.md)

---

## Global Constraints
- Target Device: iPhone 17 (`platform=iOS Simulator,name=iPhone 17`).
- All unit and integration tests must pass with 0 failures before completion.
- Maintain existing UI accessibility identifiers (`relay-control-button`, `speech-engine-picker`, etc.).
- Comply with Swift 6 Concurrency strictness without introducing data races.

## Review Focus
1. **Interleaved Multichannel Audio**: Must not crash (`EXC_BAD_ACCESS`) or truncate when audio hardware reports interleaved stereo or multichannel formats.
2. **Streaming Buffer Flush**: Last audio packet before turn-end must contain only converted frames, never uninitialized heap memory.
3. **Local AI Orphan Detection**: Running on-device dictation must never produce a dangling `completed-*.wav` that `loadAndRecoverOrphans()` mistakes for a crashed session.
4. **Main Thread Non-Blocking**: Keyboard extension UI must never block on `flock` under contention, avoiding SpringBoard watchdog `0x8badf00d`.
5. **Background Task Expiration**: Retain cycle free; expiration must release controller references cleanly.

---

## Proposed Changes

### Component 1: CoreAudio Buffer Safety & Memory Alignment (`App/Audio`)

#### [MODIFY] [`App/Audio/AudioCaptureEngine+Streaming.swift`](App/Audio/AudioCaptureEngine+Streaming.swift)
- Fix `copyBuffer()`:
  - If format is non-interleaved, copy channel-by-channel up to `frames * MemoryLayout<T>.size`.
  - If format is interleaved, copy channel 0 up to `frames * channels * MemoryLayout<T>.size` without indexing `src[1..<channels]`.
  - Alternatively, use `AudioBufferList` with `min(validBytesPerBuffer, ...)` which inherently abstracts interleaved vs non-interleaved buffers.
- Fix `streamingPCMData(from:)` and `finishStreamingPCMData()`:
  - Replace `audioBuffer.mDataByteSize` with `Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size`.

#### [MODIFY] [`Tests/AudioCaptureEngineTests.swift`](Tests/AudioCaptureEngineTests.swift)
- Add `testCopyBufferMultiChannelInterleaved()`: Verify `AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: true)` copies without crash and verifies all samples across both channels.
- Add `testFinishStreamingPCMDataDoesNotLeakCapacityBytes()`: Verify output chunk byte count equals `frameLength * 2` rather than `frameCapacity * 2`.

---

### Component 2: Local AI Dictation Storage & Recovery Hygiene (`App/Relay`)

#### [MODIFY] [`App/Relay/RelayController.swift`](App/Relay/RelayController.swift)
- Add `@ObservationIgnored var activeLocalAudioSegment: CapturedAudioSegment?` to track the audio segment during local on-device transcription.

#### [MODIFY] [`App/Relay/RelayController+Transcription.swift`](App/Relay/RelayController+Transcription.swift)
- In `finishDictationAndTranscribe(requestID:)`:
  - When `isUsingLocalTranscriber` is true, store `activeLocalAudioSegment = segment`.
- In `finalizeLocalTranscription`:
  - On successful insertion into text proxy and history, remove the temporary audio file:
    ```swift
    if let segment = activeLocalAudioSegment {
      try? FileManager.default.removeItem(at: segment.url)
      activeLocalAudioSegment = nil
    }
    ```
- In `handleLocalTranscriptionResult`:
  - On failure, stage `activeLocalAudioSegment` into `recoveryStore.stage(segment, ...)` so that it can fall back to Gemini batch or manual retry, instead of abandoning it as an untracked orphan on disk.
- In `cancelDictation()`:
  - Purge `activeLocalAudioSegment` file if non-nil.

#### [MODIFY] [`Tests/RelayControllerLocalDictationTests.swift`](Tests/RelayControllerLocalDictationTests.swift)
- Add test verifying that when local dictation succeeds, the segment file on disk is deleted and `loadAndRecoverOrphans()` finds 0 orphans.

---

### Component 3: Concurrency, Retain Cycles & IPC Hardening (`App/Relay`, `Shared/Relay`, `Tests`)

#### [MODIFY] [`App/Relay/RelayController+BackgroundTasks.swift`](App/Relay/RelayController+BackgroundTasks.swift)
- Add `[weak self]` to outer closures of `UIApplication.shared.beginBackgroundTask(withName:)` in `beginTranscriptionBackgroundTaskIfNeeded()` and `beginOCRBackgroundTaskIfNeeded()`.

#### [MODIFY] [`Shared/Relay/SharedRelayStore.swift`](Shared/Relay/SharedRelayStore.swift)
- In `publishAudioLevel`: remove `flush()` / `defaults.synchronize()` on every 50ms tick.
- In `withCommandLock`: implement non-blocking `flock(handle.fileDescriptor, LOCK_EX | LOCK_NB)` with short bounded spin/backoff (max 20ms total) before falling back to blocking flock, preventing indefinite main-thread freeze.

#### [MODIFY] [`Tests/RelayProtocolTests.swift`](Tests/RelayProtocolTests.swift)
- In `testConcurrentCommandIssuanceProducesUniqueSequences`: encapsulate `var sequences: [Int]` inside a thread-safe Sendable collector class to eliminate Swift 6 concurrency warnings.

---

## Detailed Task Breakdown

### Task 1: Fix CoreAudio Buffer Safety & Memory Alignment
**Files:**
- Modify: [`App/Audio/AudioCaptureEngine+Streaming.swift:28-65, 174-177, 211-215`](App/Audio/AudioCaptureEngine+Streaming.swift#L28-L65)
- Test: [`Tests/AudioCaptureEngineTests.swift`](Tests/AudioCaptureEngineTests.swift)

- [ ] **Step 1: Write failing unit test for interleaved audio copy and buffer capacity clamping**
```swift
// In Tests/AudioCaptureEngineTests.swift
func testCopyBufferInterleavedFormatDoesNotCrashAndPreservesSamples() throws {
  let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 2, interleaved: true))
  let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32))
  buffer.frameLength = 32
  let channelData = try XCTUnwrap(buffer.floatChannelData)
  // Channel 0 holds interleaved samples (32 frames * 2 channels = 64 floats)
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
```

- [ ] **Step 2: Run test to observe failure or crash**
Run: MobileBuildMCP `test_sim` with scheme `GeminiVoice`, simulator `iPhone 17`.
Expected: Crash/failure under current implementation due to invalid `src[1]` dereference.

- [ ] **Step 3: Implement format-aware `copyBuffer` and clamped streaming byte count**
In `App/Audio/AudioCaptureEngine+Streaming.swift`:
```swift
extension AVAudioPCMBuffer {
  func copyBuffer() -> AVAudioPCMBuffer? {
    guard frameLength > 0,
      let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)
    else {
      return nil
    }
    copy.frameLength = frameLength
    let channels = Int(format.channelCount)
    let frames = Int(frameLength)
    let isInterleaved = format.isInterleaved

    if let src = floatChannelData, let dst = copy.floatChannelData {
      if isInterleaved {
        memcpy(dst[0], src[0], frames * channels * MemoryLayout<Float>.size)
      } else {
        for channel in 0..<channels {
          memcpy(dst[channel], src[channel], frames * MemoryLayout<Float>.size)
        }
      }
      return copy
    }
    if let src = int16ChannelData, let dst = copy.int16ChannelData {
      if isInterleaved {
        memcpy(dst[0], src[0], frames * channels * MemoryLayout<Int16>.size)
      } else {
        for channel in 0..<channels {
          memcpy(dst[channel], src[channel], frames * MemoryLayout<Int16>.size)
        }
      }
      return copy
    }
    if let src = int32ChannelData, let dst = copy.int32ChannelData {
      if isInterleaved {
        memcpy(dst[0], src[0], frames * channels * MemoryLayout<Int32>.size)
      } else {
        for channel in 0..<channels {
          memcpy(dst[channel], src[channel], frames * MemoryLayout<Int32>.size)
        }
      }
      return copy
    }
    let srcBuffers = UnsafeMutableAudioBufferListPointer(self.mutableAudioBufferList)
    let dstBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
    for (src, dst) in zip(srcBuffers, dstBuffers) {
      if let srcData = src.mData, let dstData = dst.mData {
        memcpy(dstData, srcData, min(Int(src.mDataByteSize), Int(dst.mDataByteSize)))
      }
    }
    return copy
  }
}
```
And in `streamingPCMData` and `finishStreamingPCMData`:
```swift
let validBytes = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
guard let bytes = audioBuffer.mData, validBytes > 0 else { return nil }
return Data(bytes: bytes, count: validBytes)
```

- [ ] **Step 4: Run tests to verify pass**
Run: MobileBuildMCP `test_sim`.
Expected: `testCopyBufferInterleavedFormatDoesNotCrashAndPreservesSamples` and all audio tests PASS.

---

### Task 2: Fix Local Speech Transcription Disk Leak & Phantom Recovery Cards
**Files:**
- Modify: [`App/Relay/RelayController.swift:108`](App/Relay/RelayController.swift#L108)
- Modify: [`App/Relay/RelayController+Transcription.swift:128-143, 505-528`](App/Relay/RelayController+Transcription.swift#L128-L143)
- Test: [`Tests/RelayControllerLocalDictationTests.swift`](Tests/RelayControllerLocalDictationTests.swift)

- [ ] **Step 1: Write test verifying audio segment cleanup after on-device transcription**
```swift
// In Tests/RelayControllerLocalDictationTests.swift
@MainActor
func testLocalDictationSuccessDeletesAudioSegmentFile() async throws {
  let controller = makeTestRelayController()
  // Simulate successful local dictation
  // Assert FileManager.default.fileExists(atPath: segmentURL.path) == false
  // Assert store.recordings has no orphans after loadAndRecoverOrphans()
}
```

- [ ] **Step 2: Track segment and remove audio file upon successful local transcription**
In `RelayController.swift`:
```swift
@ObservationIgnored var activeLocalAudioSegment: CapturedAudioSegment?
```
In `RelayController+Transcription.swift`:
```swift
if isUsingLocalTranscriber {
  activeLocalAudioSegment = segment
  ...
}
```
In `finalizeLocalTranscription`:
```swift
if let segment = activeLocalAudioSegment {
  try? FileManager.default.removeItem(at: segment.url)
  activeLocalAudioSegment = nil
}
```
In `cancelDictation`:
```swift
if let segment = activeLocalAudioSegment {
  try? FileManager.default.removeItem(at: segment.url)
  activeLocalAudioSegment = nil
}
```

- [ ] **Step 3: Run tests to verify pass**
Run: MobileBuildMCP `test_sim`.
Expected: Local dictation tests pass with 0 disk leaks.

---

### Task 3: Eliminate Retain Cycles & Concurrency Warnings
**Files:**
- Modify: [`App/Relay/RelayController+BackgroundTasks.swift:33, 76`](App/Relay/RelayController+BackgroundTasks.swift#L33)
- Modify: [`Shared/Relay/SharedRelayStore.swift:252, 400`](Shared/Relay/SharedRelayStore.swift#L252)
- Modify: [`Tests/RelayProtocolTests.swift:166-186`](Tests/RelayProtocolTests.swift#L166-L186)

- [ ] **Step 1: Add `[weak self]` to background task closures**
```swift
taskID = UIApplication.shared.beginBackgroundTask(withName: "Finish Gemini transcription") { [weak self] in
  ...
}
```

- [ ] **Step 2: Throttle audio metering IPC and implement bounded non-blocking flock**
In `SharedRelayStore.swift`:
Remove `flush()` in `publishAudioLevel`.
In `withCommandLock`:
```swift
var acquired = false
for _ in 0..<10 {
  if flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
    acquired = true
    break
  }
  usleep(2_000)
}
if !acquired {
  _ = flock(handle.fileDescriptor, LOCK_EX)
}
```

- [ ] **Step 3: Fix Sendable closure capture in `RelayProtocolTests`**
In `Tests/RelayProtocolTests.swift`:
Collect sequences via a `@unchecked Sendable` thread-safe accumulator.

- [ ] **Step 4: Run full test suite via MobileBuildMCP**
Run: MobileBuildMCP `test_sim`.
Expected: 184+ tests passing, warnings reduced.

---

## Verification Plan

### Automated Tests
1. **Simulator Unit Test Suite**:
   ```bash
   MobileBuildMCP test_sim: { "scheme": "GeminiVoice", "simulatorName": "iPhone 17" }
   ```
   *Requirement*: 100% green tests (184+ tests), zero crashes.

### Manual Verification
1. **Interleaved Audio Stability**:
   Verify `AudioCaptureEngine` initializes properly without crashing when switching between route options in Settings.
2. **Local Voice Dictation Lifecycle**:
   Perform on-device transcription in Studio or Settings tab, close and reopen the app, and verify that the History tab contains NO phantom failed "Recovered after Gemini Voice closed" cards.
3. **Keyboard Responsiveness**:
   Tap Dictate and Cancel in rapid succession to ensure no watchdog hangs or UI lag.
