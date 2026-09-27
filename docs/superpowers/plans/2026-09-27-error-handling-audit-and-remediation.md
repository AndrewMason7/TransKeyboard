# Error Handling Audit and Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate silent failures, deadlocks, untyped errors, and orphaned recovery states across the audio capture engine, relay controller, IPC store, cloud clients, and local speech engine.

**Architecture:** 
1. AVFoundation lifecycle: Register and handle standard `AVAudioSession.interruptionNotification` and replace blocking `flock(LOCK_EX)` IPC with bounded exponential backoff polling to prevent main-thread deadlocks.
2. Error hierarchy: Replace untyped `NSError` with strongly-typed `LocalSpeechTranscriberError`, expand `RecoverableRecordingStatus.keyboardMessage(for:)` to differentiate missing API keys, auth 401/403, and rate-limiting from transport timeouts.
3. Resilience & State Integrity: Guarantee atomic file movements without destination destruction, capture immediate errors in `liveConnectionTask`, mark orphaned recordings failed upon background task expiration, and expose explicit failure feedback for OCR and retry actions.

**Tech Stack:** Swift 6.0, AVFoundation, Speech framework, URLSession WebSocket & HTTP, ActivityKit, XCTest.

**Spec:** [docs/superpowers/specs/2026-09-27-error-handling-spec.md](file:///Users/andrew/Documents/GitHub/GeminiKeyboardSample/docs/superpowers/specs/2026-09-27-error-handling-spec.md)

## Global Constraints

- Target OS: iOS 27.0+ (`arm64`), strict physical iPhone 17 hardware verification.
- Separation of Concerns: Keep `App/Audio`, `App/Relay`, `App/Gemini`, `App/LocalAI`, `Shared/Relay`, and `KeyboardExtension` strictly decoupled.
- Swift Concurrency: Ensure all async mutations and UI updates remain on `@MainActor` or inside dedicated actors.
- Zero silent swallows: Every `catch` or `try?` must either log with diagnostic context, update UI state, or return an explicit `Result`/`Error`.

## Review Focus

1. **System Call Interruptions:** Phone calls or Siri activations during an active recording must cleanly cancel or pause the recording and notify the user rather than crashing or freezing the audio tap.
2. **IPC Lock Watchdogs:** If one process terminates or suspends while holding a lock file descriptor, another process acquiring the lock must timeout gracefully within 500ms instead of causing an iOS watchdog 0x8badf00d termination.
3. **Dead Stream Speech Capture:** If Gemini Live WebSocket connection fails immediately upon dictation start, the app must not deceive the user with "Streaming live transcription…" while dropping audio into the void; it must fail fast or transition to local/batch capture.
4. **Permanent Staging Hangs:** Background processing timeout or on-device transcription errors must never leave recordings stranded with "Waiting for transcription" in the Recoverable Recordings store.
5. **Destination File Collision:** Moving an in-progress recording to a finalized destination that already exists must atomically replace the destination or use a deduplicated unique name, never destroying both source and destination.

---

### Task 1: AVAudioSession Interruption Notification Handling & Safe Recording Move

**Files:**
- Modify: `App/Audio/AudioCaptureEngine.swift`
- Modify: `App/Audio/AudioCaptureEngine+Session.swift`
- Modify: `App/Audio/AudioCaptureEngine+Recording.swift`
- Test: `Tests/AudioCaptureEngineTests.swift`

**Interfaces:**
- Consumes: `AVAudioSession.interruptionNotification`, `AVAudioSessionInterruptionTypeKey`, `AVAudioSessionInterruptionOptionKey`
- Produces: `AudioCaptureEngine.handleAudioSessionInterruption(_ notification: Notification)`

- [ ] **Step 1: Write the failing unit tests for interruption handling and move collision safety**

```swift
// Add to Tests/AudioCaptureEngineTests.swift:
func testSessionInterruptionBeganCancelsActiveSegment() {
  let engine = AudioCaptureEngine()
  // Simulate active state
  engine.isRecordingActive = true
  let notification = Notification(
    name: AVAudioSession.interruptionNotification,
    object: nil,
    userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
  )
  engine.handleAudioSessionInterruption(notification)
  XCTAssertFalse(engine.isRecordingActive)
}

func testSafeFinalizeRecordingDoesNotDestroySourceOnCollision() throws {
  let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: tempDir) }

  let sourceURL = tempDir.appendingPathComponent("source.wav")
  let targetURL = tempDir.appendingPathComponent("target.wav")
  try Data([0x01, 0x02]).write(to: sourceURL)
  try Data([0x03, 0x04]).write(to: targetURL)

  try AudioCaptureEngine.safelyMoveAndProtect(from: sourceURL, to: targetURL)
  XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))
  let targetData = try Data(contentsOf: targetURL)
  XCTAssertEqual(targetData, Data([0x01, 0x02]))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/AudioCaptureEngineTests/testSessionInterruptionBeganCancelsActiveSegment`
Expected: FAIL with "value of type 'AudioCaptureEngine' has no member 'handleAudioSessionInterruption'"

- [ ] **Step 3: Implement interruption observer and safe atomic file move**

In `App/Audio/AudioCaptureEngine.swift`:
Register `AVAudioSession.interruptionNotification` in `init()`:
```swift
observers.append(
  center.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: AVAudioSession.sharedInstance(),
    queue: .main
  ) { [weak self] notification in
    self?.handleAudioSessionInterruption(notification)
  }
)
```

In `App/Audio/AudioCaptureEngine+Session.swift`:
```swift
func handleAudioSessionInterruption(_ notification: Notification) {
  guard shouldBeRunning else { return }
  guard let userInfo = notification.userInfo,
        let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
        let type = AVAudioSession.InterruptionType(rawValue: rawType)
  else { return }

  switch type {
  case .began:
    NSLog("AUDIO_RELAY_INTERRUPTION_BEGAN route=%@", routeDescription)
    isRunning = false
    if hasActiveSegment {
      cancelSegment()
    }
  case .ended:
    let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
    NSLog("AUDIO_RELAY_INTERRUPTION_ENDED shouldResume=%d", options.contains(.shouldResume))
    if options.contains(.shouldResume) {
      scheduleRecovery(reason: "audio interruption ended with shouldResume")
    }
  @unknown default:
    break
  }
}
```

In `App/Audio/AudioCaptureEngine+Recording.swift`:
Replace `FileManager.default.moveItem` in `endSegment()` with `safelyMoveAndProtect`:
```swift
static func safelyMoveAndProtect(from sourceURL: URL, to targetURL: URL) throws {
  if FileManager.default.fileExists(atPath: targetURL.path) {
    try? FileManager.default.removeItem(at: targetURL)
  }
  try FileManager.default.moveItem(at: sourceURL, to: targetURL)
  try protectRecordingItem(at: targetURL)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/AudioCaptureEngineTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/Audio/ Tests/AudioCaptureEngineTests.swift
git commit -m "fix(audio): handle AVAudioSession interruptions and prevent move collision data loss"
```

---

### Task 2: Non-Blocking Bounded IPC Lock in SharedRelayStore

**Files:**
- Modify: `Shared/Relay/SharedRelayStore.swift`
- Test: `Tests/RelayProtocolTests.swift`

**Interfaces:**
- Consumes: `flock`, `LOCK_EX`, `LOCK_NB`, `LOCK_UN`
- Produces: `SharedRelayStore.withBoundedFileLock(url:lock:operation:)`

- [ ] **Step 1: Write failing unit test for lock timeout**

```swift
// Add to Tests/RelayProtocolTests.swift:
func testBoundedFileLockTimesOutWhenHeldExclusively() throws {
  guard let containerURL = VoiceAppGroup.containerURL else { return }
  let lockURL = containerURL.appendingPathComponent("test-timeout.lock")
  _ = FileManager.default.createFile(atPath: lockURL.path, contents: Data())
  defer { try? FileManager.default.removeItem(at: lockURL) }

  let handle = try FileHandle(forUpdating: lockURL)
  defer { try? handle.close() }
  XCTAssertEqual(flock(handle.fileDescriptor, LOCK_EX | LOCK_NB), 0)

  let store = SharedRelayStore()
  var executed = false
  // Attempt to acquire lock with 100ms timeout
  let acquired = store.withBoundedFileLock(url: lockURL, timeoutMs: 100) {
    executed = true
  }
  XCTAssertFalse(acquired)
  XCTAssertFalse(executed)
  _ = flock(handle.fileDescriptor, LOCK_UN)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RelayProtocolTests/testBoundedFileLockTimesOutWhenHeldExclusively`
Expected: FAIL with "value of type 'SharedRelayStore' has no member 'withBoundedFileLock'"

- [ ] **Step 3: Implement bounded exponential backoff in `SharedRelayStore`**

In `Shared/Relay/SharedRelayStore.swift`:
Replace blocking `_ = flock(handle.fileDescriptor, LOCK_EX)` in `withCommandLock`, `withResultLock`, and `withLaunchRequestLock` with bounded polling:
```swift
@discardableResult
func withBoundedFileLock<T>(
  url: URL,
  timeoutMs: Int = 300,
  operation: () -> T
) -> T? {
  if !FileManager.default.fileExists(atPath: url.path) {
    _ = FileManager.default.createFile(atPath: url.path, contents: Data())
  }
  guard let handle = try? FileHandle(forUpdating: url) else {
    return operation()
  }
  defer {
    try? handle.close()
  }

  let startTime = DispatchTime.now()
  var acquired = false
  var sleepIntervalMicroseconds: useconds_t = 1_000
  let deadline = startTime + .milliseconds(timeoutMs)

  while DispatchTime.now() < deadline {
    if flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
      acquired = true
      break
    }
    usleep(sleepIntervalMicroseconds)
    sleepIntervalMicroseconds = min(sleepIntervalMicroseconds * 2, 20_000)
  }

  guard acquired else {
    NSLog("SHARED_RELAY_STORE_LOCK_TIMEOUT url=%@", url.lastPathComponent)
    return nil
  }

  defer {
    _ = flock(handle.fileDescriptor, LOCK_UN)
  }
  return operation()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RelayProtocolTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Shared/Relay/SharedRelayStore.swift Tests/RelayProtocolTests.swift
git commit -m "fix(relay): replace blocking flock with bounded timeout to prevent watchdog deadlocks"
```

---

### Task 3: Fail-Fast Live Streaming Connection & Error Propagation

**Files:**
- Modify: `App/Relay/RelayController+Dictation.swift`
- Modify: `App/Relay/RelayController+Transcription.swift`
- Test: `Tests/GeminiLiveSpeechSessionTests.swift`
- Test: `Tests/RelayControllerTests.swift`

**Interfaces:**
- Consumes: `GeminiLiveSpeechSession.connect`
- Produces: Early fallback or error publication if connection fails during active dictation

- [ ] **Step 1: Write failing unit test for connection failure during dictation**

```swift
// Add to Tests/RelayControllerTests.swift:
func testDictationAbortsImmediatelyWhenLiveConnectionFailsFast() async throws {
  let controller = makeRelayController()
  controller.configuration.speechEngineMode = .geminiLive
  controller.configuration.apiKey = "invalid-key"
  
  controller.beginDictation(requestID: "req-fail-fast", action: .transcribe)
  // Give task brief turn to fail
  try await Task.sleep(nanoseconds: 200_000_000)
  
  XCTAssertEqual(controller.status, .error)
  XCTAssertTrue(controller.statusMessage.contains("credential") || controller.statusMessage.contains("failed"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RelayControllerTests/testDictationAbortsImmediatelyWhenLiveConnectionFailsFast`
Expected: FAIL (status remains `.recording` because connection error is unobserved until finish)

- [ ] **Step 3: Monitor connection task and fail fast in RelayController**

In `App/Relay/RelayController+Dictation.swift`:
Attach a failure monitor to `liveConnectionTask`:
```swift
liveConnectionTask = Task { [weak self, weak liveSession] in
  do {
    try await liveSession?.connect(credential: .apiKey(apiKey))
  } catch {
    Task { @MainActor [weak self] in
      guard let self, self.activeRequestID == requestID else { return }
      NSLog("LIVE_CONNECTION_EARLY_FAILURE request=%@ error=%@", requestID, error.localizedDescription)
      self.cancelLiveStream(matching: requestID)
      self.publish(
        .error,
        message: "Gemini Live connection failed: \(error.localizedDescription)",
        activeRequestID: requestID,
        activeDictationAction: action
      )
      self.cancelDictation(message: "Connection failed: \(error.localizedDescription)")
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RelayControllerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/Relay/RelayController+Dictation.swift Tests/RelayControllerTests.swift
git commit -m "fix(relay): monitor liveConnectionTask for early connection failure"
```

---

### Task 4: Granular Error Mapping and Status Classification

**Files:**
- Modify: `App/Recovery/RecoverableRecordingStore.swift`
- Modify: `App/LocalAI/LocalSpeechTranscriber.swift`
- Test: `Tests/RecoverableRecordingStoreTests.swift`
- Test: `Tests/LocalSpeechTranscriberTests.swift`

**Interfaces:**
- Consumes: `GeminiTranscriptionError`, `LocalSpeechTranscriberError`, `URLError`
- Produces: `RecoverableRecordingStatus.keyboardMessage(for:) -> String` with clear action prompts

- [ ] **Step 1: Write failing unit tests for credential & rate limit messages**

```swift
// Add to Tests/RecoverableRecordingStoreTests.swift:
func testKeyboardMessageReflectsMissingOrInvalidAPIKey() {
  let missingKeyError = GeminiTranscriptionError.missingAPIKey
  let msg1 = RecoverableRecordingStatus.keyboardMessage(for: missingKeyError)
  XCTAssertEqual(msg1, "Add a Gemini API key in Gemini Voice Settings.")

  let authError = GeminiTranscriptionError.service(statusCode: 401, message: "API key not valid")
  let msg2 = RecoverableRecordingStatus.keyboardMessage(for: authError)
  XCTAssertEqual(msg2, "Invalid Gemini API key — update in Gemini Voice.")

  let quotaError = GeminiTranscriptionError.service(statusCode: 429, message: "Resource exhausted")
  let msg3 = RecoverableRecordingStatus.keyboardMessage(for: quotaError)
  XCTAssertEqual(msg3, "Gemini rate limit exceeded — retry shortly.")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RecoverableRecordingStoreTests/testKeyboardMessageReflectsMissingOrInvalidAPIKey`
Expected: FAIL with "Transcription failed — recording saved. Retry in Gemini Voice."

- [ ] **Step 3: Implement granular error cases in `RecoverableRecordingStatus`**

In `App/Recovery/RecoverableRecordingStore.swift`:
```swift
enum RecoverableRecordingStatus {
  static func keyboardMessage(for error: Error) -> String {
    if let transcriptionError = error as? GeminiTranscriptionError {
      switch transcriptionError {
      case .missingAPIKey:
        return "Add a Gemini API key in Gemini Voice Settings."
      case .service(let statusCode, _):
        switch statusCode {
        case 401, 403:
          return "Invalid Gemini API key — update in Gemini Voice."
        case 429:
          return "Gemini rate limit exceeded — retry shortly."
        default:
          break
        }
      default:
        break
      }
    }

    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
      switch nsError.code {
      case NSURLErrorTimedOut:
        return "Timed out — recording saved. Retry in Gemini Voice."
      case NSURLErrorNotConnectedToInternet,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorCannotFindHost,
        NSURLErrorDNSLookupFailed:
        return "Connection failed — recording saved. Retry in Gemini Voice."
      default:
        break
      }
    }
    return "Transcription failed — recording saved. Retry in Gemini Voice."
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RecoverableRecordingStoreTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/Recovery/RecoverableRecordingStore.swift Tests/RecoverableRecordingStoreTests.swift
git commit -m "fix(recovery): provide actionable keyboard error messages for auth, quota, and transport failures"
```

---

### Task 5: Recovery State Leak & Background Task Expiration Fix

**Files:**
- Modify: `App/Relay/RelayController+BackgroundTasks.swift`
- Modify: `App/Relay/RelayController+Transcription.swift`
- Modify: `App/Relay/RelayController+Recovery.swift`
- Test: `Tests/RelayControllerTests.swift`

**Interfaces:**
- Consumes: `UIBackgroundTaskIdentifier`, `recoveryStore.markFailed`
- Produces: Correct terminal state marking for background expired recordings and user feedback on disabled retries

- [ ] **Step 1: Write failing test for background expiration marking**

```swift
// Add to Tests/RelayControllerTests.swift:
func testTranscriptionBackgroundExpirationMarksRecordingFailed() throws {
  let controller = makeRelayController()
  let recordingID = UUID()
  controller.processingRecordingID = recordingID
  
  controller.transcriptionBackgroundTimeExpired()
  
  XCTAssertNil(controller.processingRecordingID)
  // Verify recording store recorded the failure message
  let item = controller.recoveryStore.recordings.first { $0.id == recordingID }
  XCTAssertEqual(item?.lastError, "Processing timed out in background — recording preserved.")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RelayControllerTests/testTranscriptionBackgroundExpirationMarksRecordingFailed`
Expected: FAIL

- [ ] **Step 3: Update background expiration and retry guard feedback**

In `App/Relay/RelayController+BackgroundTasks.swift`:
```swift
func transcriptionBackgroundTimeExpired() {
  transcriptionGeneration += 1
  transcriptionTask?.cancel()
  transcriptionTask = nil
  if let recordingID = processingRecordingID {
    recoveryStore.markFailed(
      id: recordingID,
      message: "Processing timed out in background — recording preserved."
    )
    refreshRecoverableRecordings()
  }
  processingRequestID = nil
  processingRecordingID = nil
  recoveryRetryTask?.cancel()
  recoveryRetryTask = nil
  cancelLiveStream()
  let message = "Processing timed out — recording saved. Retry in Gemini Voice."
  if isRelayRunning {
    publish(.error, message: message)
    markRelayActivityAndScheduleIdleShutdown()
  } else {
    statusMessage = message
  }
  endTranscriptionBackgroundTaskIfNeeded()
}
```

In `App/Relay/RelayController+Recovery.swift`:
Provide user feedback if retry is blocked:
```swift
func retryRecording(_ recording: RecoverableRecording) {
  guard retryingRecordingID == nil,
    status != .recording,
    status != .transcribing,
    recording.transcriptSaved != true
  else { return }

  guard configuration.hasUsableAPIKey else {
    statusMessage = "Add a Gemini API key in Settings before retrying."
    return
  }

  guard let audioURL = recoveryStore.fileURL(for: recording) else {
    statusMessage = "Audio file for this recording is missing."
    return
  }
  ...
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./Scripts/test.sh -u -only-testing:GeminiVoiceTests/RelayControllerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add App/Relay/ Tests/RelayControllerTests.swift
git commit -m "fix(relay): record background task expiration in recovery store and provide retry feedback"
```

---

### Task 6: Full Device Regression Verification

**Files:**
- Execute verification suite on physical device

- [ ] **Step 1: Execute all unit tests on the physical iPhone 17**

Run: `./Scripts/test.sh -u`
Expected: All unit tests in `GeminiVoiceTests` and `GeminiKeyboardPortTests` PASS.

- [ ] **Step 2: Deploy and verify launch on device**

Run: `./Scripts/deploy-device.sh 00008150-001943D63E13401C`
Launch: `xcrun devicectl device process launch --device 00008150-001943D63E13401C --terminate-existing com.example.GeminiVoiceSample`
Expected: App launches cleanly with zero startup regressions.
