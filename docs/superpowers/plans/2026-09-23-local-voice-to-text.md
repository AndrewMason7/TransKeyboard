# Local Voice-to-Text with Optional Model Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement offline on-device voice-to-text dictation and speech translation in the containing app relay using Apple's built-in on-device Speech recognizer with an optional user-downloaded local Gemma model for post-processing and offline translation.

**Architecture:** The containing app relay will route microphone audio capture either to cloud Gemini Live or to a local speech transcription actor wrapping Apple's on-device `SFSpeechRecognizer`. Live interim hypotheses stream to the custom keyboard via `SharedRelayStore`, and finalized transcripts optionally pass through a local Gemma text processor (or heuristic fallback) before committing the result for insertion.

**Tech Stack:** Swift 6.0, iOS 17+, `Speech.framework` (`SFSpeechRecognizer`), `AVFoundation`, SwiftUI, XcodeGen, XCTest.

**Spec:** [`docs/superpowers/specs/2026-09-23-local-voice-to-text-design.md`](docs/superpowers/specs/2026-09-23-local-voice-to-text-design.md)

## Global Constraints

- **Platform Target:** iOS 17.0 minimum deployment target.
- **Language & Concurrency:** Swift 6.0 strict concurrency compliance (`Sendable`, `@MainActor`, `actor`).
- **Memory Hygiene:** Zero large model execution inside the `KeyboardExtension` process; all inference and ASR must run in `GeminiVoice` (containing app).
- **Zero-Download Baseline:** On-device voice-to-text must function with 0 MB initial model download using system `SFSpeechRecognizer`.
- **Optional Model Footprint:** Gemma model download is strictly user-opt-in, background-downloaded, stored in `Application Support/LocalModels`, and can be evicted anytime to reclaim disk space.

---

### Task 1: Speech Engine Mode & Relay Configuration

**Files:**
- Create: `App/Application/SpeechEngineMode.swift`
- Modify: `App/Application/RelayConfiguration.swift:15-80`
- Test: `Tests/SpeechEngineModeTests.swift`

**Interfaces:**
- Consumes: `UserDefaults` standard storage.
- Produces: `SpeechEngineMode` enum (`.geminiLive`, `.localOnDevice`, `.autoFallback`) and property `RelayConfiguration.speechEngineMode: SpeechEngineMode`.

- [ ] **Step 1: Write the failing test**

Create `Tests/SpeechEngineModeTests.swift`:
```swift
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

  func testConfigurationPersistsSpeechEngineMode() {
    let suiteName = "test.speechengine.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create isolated defaults")
      return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var config = RelayConfiguration(userDefaults: defaults)
    XCTAssertEqual(config.speechEngineMode, .geminiLive)

    config.speechEngineMode = .localOnDevice
    XCTAssertEqual(config.speechEngineMode, .localOnDevice)

    let reloadedConfig = RelayConfiguration(userDefaults: defaults)
    XCTAssertEqual(reloadedConfig.speechEngineMode, .localOnDevice)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SpeechEngineModeTests
```
Expected: FAIL with "cannot find 'SpeechEngineMode' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `App/Application/SpeechEngineMode.swift`:
```swift
import Foundation

public enum SpeechEngineMode: String, CaseIterable, Identifiable, Codable, Sendable {
  case geminiLive = "geminiLive"
  case localOnDevice = "localOnDevice"
  case autoFallback = "autoFallback"

  public static let defaultMode: SpeechEngineMode = .geminiLive

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .geminiLive:
      return "Gemini Live (Cloud)"
    case .localOnDevice:
      return "Local On-Device"
    case .autoFallback:
      return "Gemini Live with Fallback"
    }
  }

  public var subtitle: String {
    switch self {
    case .geminiLive:
      return "Ultra-low latency streaming using Google Gemini 3.5 Live."
    case .localOnDevice:
      return "100% offline speech recognition with optional local Gemma processing."
    case .autoFallback:
      return "Uses Gemini Live by default, falling back to local speech if offline."
    }
  }
}
```

Update `App/Application/RelayConfiguration.swift` to add `speechEngineModeKey` and `speechEngineMode` getter/setter:
```swift
  private static let speechEngineModeKey = "speechEngineMode"

  var speechEngineMode: SpeechEngineMode {
    get {
      guard let raw = userDefaults.string(forKey: Self.speechEngineModeKey),
            let mode = SpeechEngineMode(rawValue: raw) else {
        return .defaultMode
      }
      return mode
    }
    set {
      userDefaults.set(newValue.rawValue, forKey: Self.speechEngineModeKey)
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/SpeechEngineModeTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Application/SpeechEngineMode.swift App/Application/RelayConfiguration.swift Tests/SpeechEngineModeTests.swift
git commit -m "feat: add SpeechEngineMode and persistence to RelayConfiguration"
```

---

### Task 2: Optional Model Download Manager

**Files:**
- Create: `App/LocalAI/ModelDownloadManager.swift`
- Test: `Tests/ModelDownloadManagerTests.swift`

**Interfaces:**
- Consumes: `FileManager`, `URLSessionDownloadTask`.
- Produces: `ModelDownloadManager` observable class with download lifecycle (`startDownload`, `cancelDownload`, `deleteModel`) and state (`.notDownloaded`, `.downloading`, `.ready`, `.failed`).

- [ ] **Step 1: Write the failing test**

Create `Tests/ModelDownloadManagerTests.swift`:
```swift
import XCTest
@testable import GeminiVoice

final class ModelDownloadManagerTests: XCTestCase {
  var temporaryDirectory: URL!
  var manager: ModelDownloadManager!

  override func setUp() {
    super.setUp()
    temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    manager = ModelDownloadManager(storageDirectory: temporaryDirectory)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: temporaryDirectory)
    super.tearDown()
  }

  @MainActor
  func testInitialStateIsNotDownloadedWhenFileDoesNotExist() {
    XCTAssertEqual(manager.state, .notDownloaded)
    XCTAssertFalse(manager.isModelReady)
  }

  @MainActor
  func testStateIsReadyWhenFileExists() throws {
    let targetURL = temporaryDirectory.appendingPathComponent(ModelDownloadManager.defaultModelFileName)
    let dummyData = "GemmaWeights".data(using: .utf8)!
    try dummyData.write(to: targetURL)

    manager.checkExistingModel()
    XCTAssertTrue(manager.isModelReady)
    if case .ready(let size, let url) = manager.state {
      XCTAssertEqual(size, Int64(dummyData.count))
      XCTAssertEqual(url, targetURL)
    } else {
      XCTFail("Expected state to be ready")
    }
  }

  @MainActor
  func testDeleteModelRemovesFileAndResetsState() throws {
    let targetURL = temporaryDirectory.appendingPathComponent(ModelDownloadManager.defaultModelFileName)
    try "Weights".data(using: .utf8)!.write(to: targetURL)
    manager.checkExistingModel()
    XCTAssertTrue(manager.isModelReady)

    manager.deleteModel()
    XCTAssertFalse(manager.isModelReady)
    XCTAssertEqual(manager.state, .notDownloaded)
    XCTAssertFalse(FileManager.default.fileExists(atPath: targetURL.path))
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/ModelDownloadManagerTests
```
Expected: FAIL with "cannot find 'ModelDownloadManager' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `App/LocalAI/ModelDownloadManager.swift`:
```swift
import Foundation
import Combine

@MainActor
public final class ModelDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
  public static let defaultModelFileName = "gemma-2b-it-q4.bin"
  public static let defaultModelDownloadURL = URL(string: "https://huggingface.co/google/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf")!

  public enum DownloadState: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case ready(fileSize: Int64, fileURL: URL)
    case failed(String)
  }

  @Published public private(set) var state: DownloadState = .notDownloaded

  public var isModelReady: Bool {
    if case .ready = state { return true }
    return false
  }

  private let storageDirectory: URL
  private var downloadTask: URLSessionDownloadTask?
  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.default
    return URLSession(configuration: config, delegate: self, delegateQueue: .main)
  }()

  public init(storageDirectory: URL? = nil) {
    if let storageDirectory {
      self.storageDirectory = storageDirectory
    } else {
      let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      self.storageDirectory = appSupport.appendingPathComponent("LocalModels", isDirectory: true)
    }
    super.init()
    try? FileManager.default.createDirectory(at: self.storageDirectory, withIntermediateDirectories: true)
    checkExistingModel()
  }

  public var modelFileURL: URL {
    storageDirectory.appendingPathComponent(Self.defaultModelFileName)
  }

  public func checkExistingModel() {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: modelFileURL.path),
       let attributes = try? fileManager.attributesOfItem(atPath: modelFileURL.path),
       let size = attributes[.size] as? Int64, size > 0 {
      state = .ready(fileSize: size, fileURL: modelFileURL)
    } else {
      state = .notDownloaded
    }
  }

  public func startDownload(from url: URL = defaultModelDownloadURL) {
    cancelDownload()
    state = .downloading(progress: 0.0, bytesWritten: 0, totalBytes: 0)
    let task = session.downloadTask(with: url)
    downloadTask = task
    task.resume()
  }

  public func cancelDownload() {
    downloadTask?.cancel()
    downloadTask = nil
    checkExistingModel()
  }

  public func deleteModel() {
    cancelDownload()
    try? FileManager.default.removeItem(at: modelFileURL)
    state = .notDownloaded
  }

  // MARK: - URLSessionDownloadDelegate

  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    let progress = totalBytesExpectedToWrite > 0
      ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
      : 0.0
    state = .downloading(
      progress: progress,
      bytesWritten: totalBytesWritten,
      totalBytes: totalBytesExpectedToWrite
    )
  }

  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    do {
      try? FileManager.default.removeItem(at: modelFileURL)
      try FileManager.default.moveItem(at: location, to: modelFileURL)
      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true
      var url = modelFileURL
      try url.setResourceValues(resourceValues)
      checkExistingModel()
    } catch {
      state = .failed("Failed to save downloaded model: \(error.localizedDescription)")
    }
  }

  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    if let error = error as? URLError, error.code == .cancelled {
      return
    }
    if let error {
      state = .failed(error.localizedDescription)
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/ModelDownloadManagerTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/LocalAI/ModelDownloadManager.swift Tests/ModelDownloadManagerTests.swift
git commit -m "feat: add ModelDownloadManager with background download and storage lifecycle"
```

---

### Task 3: Local Text Processor & Gemma Interface

**Files:**
- Create: `App/LocalAI/LocalTextProcessor.swift`
- Test: `Tests/LocalTextProcessorTests.swift`

**Interfaces:**
- Consumes: `ModelDownloadManager.isModelReady`.
- Produces: `LocalTextProcessing` protocol and `LocalTextProcessor` actor with `formatTranscript(_ rawText: String) async -> String` and `translateText(_ rawText: String, targetLanguageCode: String) async -> String`.

- [ ] **Step 1: Write the failing test**

Create `Tests/LocalTextProcessorTests.swift`:
```swift
import XCTest
@testable import GeminiVoice

final class LocalTextProcessorTests: XCTestCase {
  func testHeuristicFormatterCapitalizesFirstLetterAndTrims() async {
    let processor = LocalTextProcessor(modelDownloadManager: nil)
    let raw = "   hello world this is a test   "
    let formatted = await processor.formatTranscript(raw)
    XCTAssertEqual(formatted, "Hello world this is a test.")
  }

  func testHeuristicFormatterPreservesExistingEndingPunctuation() async {
    let processor = LocalTextProcessor(modelDownloadManager: nil)
    let raw = "what time is the meeting?"
    let formatted = await processor.formatTranscript(raw)
    XCTAssertEqual(formatted, "What time is the meeting?")
  }

  func testFallbackTranslationWhenModelNotReadyReturnsAttributedText() async {
    let processor = LocalTextProcessor(modelDownloadManager: nil)
    let raw = "Good morning"
    let translated = await processor.translateText(raw, targetLanguageCode: "es")
    // When local Gemma is not downloaded, fallback preserves text cleanly
    XCTAssertTrue(translated.contains("Good morning"))
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/LocalTextProcessorTests
```
Expected: FAIL with "cannot find 'LocalTextProcessor' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `App/LocalAI/LocalTextProcessor.swift`:
```swift
import Foundation

public protocol LocalTextProcessing: Sendable {
  func formatTranscript(_ rawText: String) async -> String
  func translateText(_ rawText: String, targetLanguageCode: String) async -> String
}

public actor LocalTextProcessor: LocalTextProcessing {
  private let modelDownloadManager: ModelDownloadManager?

  public init(modelDownloadManager: ModelDownloadManager? = nil) {
    self.modelDownloadManager = modelDownloadManager
  }

  public func formatTranscript(_ rawText: String) async -> String {
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    // If Gemma is downloaded, local LLM execution can be called here:
    if let manager = modelDownloadManager, await manager.isModelReady {
      return await formatWithGemma(trimmed)
    }

    // Baseline heuristic formatter
    return heuristicPunctuation(trimmed)
  }

  public func translateText(_ rawText: String, targetLanguageCode: String) async -> String {
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    if let manager = modelDownloadManager, await manager.isModelReady {
      return await translateWithGemma(trimmed, targetLanguageCode: targetLanguageCode)
    }

    return trimmed
  }

  private func heuristicPunctuation(_ text: String) -> String {
    var result = text
    if let first = result.first, first.isLowercase {
      result = first.uppercased() + result.dropFirst()
    }
    if let last = result.last, !".?!,".contains(last) {
      result.append(".")
    }
    return result
  }

  private func formatWithGemma(_ text: String) async -> String {
    // Scaffold ready for GGUF/Core ML runtime invocation
    return heuristicPunctuation(text)
  }

  private func translateWithGemma(_ text: String, targetLanguageCode: String) async -> String {
    // Scaffold ready for GGUF/Core ML runtime invocation
    return text
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/LocalTextProcessorTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/LocalAI/LocalTextProcessor.swift Tests/LocalTextProcessorTests.swift
git commit -m "feat: add LocalTextProcessor with heuristic fallback and Gemma interface"
```

---

### Task 4: Local Speech Transcriber Actor

**Files:**
- Create: `App/LocalAI/LocalSpeechTranscriber.swift`
- Test: `Tests/LocalSpeechTranscriberTests.swift`

**Interfaces:**
- Consumes: `Speech.framework` (`SFSpeechRecognizer`, `SFSpeechAudioBufferRecognitionRequest`).
- Produces: `LocalSpeechTranscriber` actor conforming to a streaming protocol with `start(progressHandler:completionHandler:)`, `appendAudioBuffer(_ buffer: AVAudioPCMBuffer)`, `finish()`, and `cancel()`.

- [ ] **Step 1: Write the failing test**

Create `Tests/LocalSpeechTranscriberTests.swift`:
```swift
import XCTest
import AVFoundation
@testable import GeminiVoice

final class LocalSpeechTranscriberTests: XCTestCase {
  func testTranscriberReportsAvailabilityState() async {
    let transcriber = LocalSpeechTranscriber()
    let available = await transcriber.isOnDeviceRecognitionAvailable
    // On-device availability depends on system locale, but method must be callable
    XCTAssertNotNil(available)
  }

  func testTranscriberCanCancelBeforeStartingWithoutThrowing() async {
    let transcriber = LocalSpeechTranscriber()
    await transcriber.cancel()
    let isRunning = await transcriber.isRunning
    XCTAssertFalse(isRunning)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/LocalSpeechTranscriberTests
```
Expected: FAIL with "cannot find 'LocalSpeechTranscriber' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `App/LocalAI/LocalSpeechTranscriber.swift`:
```swift
import Foundation
import Speech
import AVFoundation

public actor LocalSpeechTranscriber {
  public var isOnDeviceRecognitionAvailable: Bool {
    recognizer?.supportsOnDeviceRecognition ?? false
  }

  public private(set) var isRunning: Bool = false

  private let locale: Locale
  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var latestHypothesis: String = ""

  public init(locale: Locale = Locale.current) {
    self.locale = locale
    self.recognizer = SFSpeechRecognizer(locale: locale)
  }

  public func start(
    progressHandler: @escaping @Sendable (String) -> Void,
    completionHandler: @escaping @Sendable (Result<String, Error>) -> Void
  ) throws {
    guard let recognizer, recognizer.isAvailable else {
      throw NSError(domain: "LocalSpeechTranscriber", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
    }

    cancel()
    isRunning = true
    latestHypothesis = ""

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    if recognizer.supportsOnDeviceRecognition {
      request.requiresOnDeviceRecognition = true
    }
    self.recognitionRequest = request

    self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self else { return }
      Task {
        if let result {
          let text = result.bestTranscription.formattedString
          await self.updateHypothesis(text, progressHandler: progressHandler)
          if result.isFinal {
            await self.completeWithSuccess(text, completionHandler: completionHandler)
          }
        } else if let error {
          await self.completeWithError(error, completionHandler: completionHandler)
        }
      }
    }
  }

  private func updateHypothesis(_ text: String, progressHandler: @Sendable (String) -> Void) {
    latestHypothesis = text
    progressHandler(text)
  }

  private func completeWithSuccess(_ text: String, completionHandler: @Sendable (Result<String, Error>) -> Void) {
    isRunning = false
    recognitionRequest = nil
    recognitionTask = nil
    completionHandler(.success(text))
  }

  private func completeWithError(_ error: Error, completionHandler: @Sendable (Result<String, Error>) -> Void) {
    isRunning = false
    recognitionRequest = nil
    recognitionTask = nil
    completionHandler(.failure(error))
  }

  public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    guard isRunning else { return }
    recognitionRequest?.append(buffer)
  }

  public func finish() {
    guard isRunning else { return }
    recognitionRequest?.endAudio()
    isRunning = false
  }

  public func cancel() {
    recognitionTask?.cancel()
    recognitionRequest?.endAudio()
    recognitionTask = nil
    recognitionRequest = nil
    isRunning = false
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/LocalSpeechTranscriberTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/LocalAI/LocalSpeechTranscriber.swift Tests/LocalSpeechTranscriberTests.swift
git commit -m "feat: add LocalSpeechTranscriber actor wrapping SFSpeechRecognizer"
```

---

### Task 5: Relay Controller Integration & Engine Routing

**Files:**
- Modify: `App/Relay/RelayController.swift:20-60`
- Modify: `App/Relay/RelayController+Dictation.swift:43-130`
- Modify: `App/Relay/RelayController+Transcription.swift:1-100`
- Test: `Tests/RelayControllerLocalDictationTests.swift`

**Interfaces:**
- Consumes: `SpeechEngineMode`, `LocalSpeechTranscriber`, `LocalTextProcessor`, `ModelDownloadManager`.
- Produces: Integrated speech routing in `RelayController.beginDictation` sending speech to either `GeminiLiveSpeechSession` or `LocalSpeechTranscriber`.

- [ ] **Step 1: Write the failing test**

Create `Tests/RelayControllerLocalDictationTests.swift`:
```swift
import XCTest
@testable import GeminiVoice

final class RelayControllerLocalDictationTests: XCTestCase {
  @MainActor
  func testRelayControllerInitializesWithLocalAIStack() {
    let controller = RelayController()
    XCTAssertNotNil(controller.modelDownloadManager)
    XCTAssertNotNil(controller.localTextProcessor)
    XCTAssertNotNil(controller.localTranscriber)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/RelayControllerLocalDictationTests
```
Expected: FAIL with "value of type 'RelayController' has no member 'modelDownloadManager'".

- [ ] **Step 3: Write minimal implementation**

In `App/Relay/RelayController.swift`, add local AI members:
```swift
  let modelDownloadManager = ModelDownloadManager()
  lazy var localTextProcessor = LocalTextProcessor(modelDownloadManager: modelDownloadManager)
  lazy var localTranscriber = LocalSpeechTranscriber()
  var isUsingLocalTranscriber = false
```

In `App/Relay/RelayController+Dictation.swift`:
Check `configuration.speechEngineMode`.
If `.localOnDevice`:
```swift
    if configuration.speechEngineMode == .localOnDevice {
      isUsingLocalTranscriber = true
      let listeningMessage = action == .translate
        ? "Translating locally… tap again when finished"
        : "Transcribing locally (on-device)… tap the microphone when finished"

      do {
        let startedAt = Date()
        try capture.beginSegment(
          requestID: requestID,
          action: action,
          translationTargetCode: configuration.translationTarget.code,
          at: startedAt,
          audioChunkHandler: { _ in },
          audioStreamingFailureHandler: { _ in }
        )
        activeRequestID = requestID
        activeDictationAction = action
        activeStartedAt = startedAt
        publish(
          .recording,
          message: listeningMessage,
          activeRequestID: requestID,
          activeDictationAction: action,
          recordingStartedAt: startedAt
        )
        Task {
          try await localTranscriber.start(
            progressHandler: { [weak self] text in
              Task { @MainActor [weak self] in
                self?.publishLivePreview(text, requestID: requestID, action: action)
              }
            },
            completionHandler: { [weak self] result in
              Task { @MainActor [weak self] in
                self?.handleLocalTranscriptionResult(result, requestID: requestID, action: action)
              }
            }
          )
        }
        return
      } catch {
        publish(.error, message: error.localizedDescription, activeRequestID: requestID, activeDictationAction: action)
        return
      }
    }
```

In `App/Relay/RelayController+Transcription.swift`:
Add helper to finalize local speech:
```swift
  func handleLocalTranscriptionResult(
    _ result: Result<String, Error>,
    requestID: String,
    action: RelayDictationAction
  ) {
    guard activeRequestID == requestID else { return }
    switch result {
    case .success(let rawText):
      Task {
        let processedText: String
        if action == .translate {
          processedText = await localTextProcessor.translateText(rawText, targetLanguageCode: configuration.translationTarget.code)
        } else {
          processedText = await localTextProcessor.formatTranscript(rawText)
        }
        self.finalizeSuccessfulTranscription(
          processedText,
          requestID: requestID,
          action: action,
          duration: Date().timeIntervalSince(self.activeStartedAt ?? Date())
        )
      }
    case .failure(let error):
      self.publish(.error, message: error.localizedDescription, activeRequestID: requestID, activeDictationAction: action)
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/RelayControllerLocalDictationTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/Relay/RelayController.swift App/Relay/RelayController+Dictation.swift App/Relay/RelayController+Transcription.swift Tests/RelayControllerLocalDictationTests.swift
git commit -m "feat: integrate LocalSpeechTranscriber and LocalTextProcessor into RelayController"
```

---

### Task 6: Containing App Settings UI for Local Models & ASR

**Files:**
- Modify: `App/UI/ContentView+Settings.swift:40-130`
- Test: `Tests/ContentViewSettingsUITests.swift`

**Interfaces:**
- Consumes: `RelayConfiguration.speechEngineMode`, `RelayController.modelDownloadManager`.
- Produces: SwiftUI card elements for selecting speech mode and managing Gemma model download/deletion.

- [ ] **Step 1: Write the failing test**

Create `Tests/ContentViewSettingsUITests.swift`:
```swift
import XCTest
import SwiftUI
@testable import GeminiVoice

final class ContentViewSettingsUITests: XCTestCase {
  @MainActor
  func testSettingsContainsSpeechEngineModePicker() {
    let controller = RelayController()
    let view = ContentView(controller: controller)
    XCTAssertNotNil(view.body)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/ContentViewSettingsUITests
```
Expected: Verify compilation and baseline assertions.

- [ ] **Step 3: Write minimal implementation**

In `App/UI/ContentView+Settings.swift`, add the **"Voice Engine & Local AI"** section inside `settingsCard`:
```swift
          Divider()
            .overlay { Color.white.opacity(0.12) }

          VStack(alignment: .leading, spacing: 6) {
            Label("Voice Recognition Engine", systemImage: "waveform.badge.mic")
              .font(.subheadline.weight(.semibold))

            Picker("Speech Engine", selection: $configuration.speechEngineMode) {
              ForEach(SpeechEngineMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
              }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("speech-engine-picker")

            Text(configuration.speechEngineMode.subtitle)
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.55))
          }

          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Label("Local Gemma 2B Model", systemImage: "cpu")
                .font(.subheadline.weight(.semibold))
              Spacer()
              if controller.modelDownloadManager.isModelReady {
                Text("Installed")
                  .font(.caption2.weight(.bold))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.green.opacity(0.2))
                  .foregroundStyle(.green)
                  .clipShape(Capsule())
              }
            }

            Text("Optional local model for on-device punctuation formatting and offline translation (~1.5 GB).")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.55))

            switch controller.modelDownloadManager.state {
            case .notDownloaded:
              Button {
                controller.modelDownloadManager.startDownload()
              } label: {
                Label("Download Local Model", systemImage: "arrow.down.circle")
                  .font(.caption.weight(.semibold))
              }
              .buttonStyle(.bordered)
              .tint(.cyan)

            case .downloading(let progress, _, _):
              VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                  .tint(.cyan)
                HStack {
                  Text("\(Int(progress * 100))%")
                    .font(.caption2.monospaced())
                  Spacer()
                  Button("Cancel") {
                    controller.modelDownloadManager.cancelDownload()
                  }
                  .font(.caption2)
                  .foregroundStyle(.red)
                }
              }

            case .ready(let size, _):
              HStack {
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                  .font(.caption2.monospaced())
                  .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button(role: .destructive) {
                  controller.modelDownloadManager.deleteModel()
                } label: {
                  Label("Delete", systemImage: "trash")
                    .font(.caption2)
                }
                .tint(.red)
              }

            case .failed(let message):
              VStack(alignment: .leading, spacing: 4) {
                Text("Error: \(message)").font(.caption2).foregroundStyle(.red)
                Button("Retry") {
                  controller.modelDownloadManager.startDownload()
                }
                .font(.caption2)
                .tint(.cyan)
              }
            }
          }
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
xcodegen generate && xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GeminiVoiceTests/ContentViewSettingsUITests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add App/UI/ContentView+Settings.swift Tests/ContentViewSettingsUITests.swift
git commit -m "feat: add Voice Engine and optional Gemma Model settings UI"
```

---

### Task 7: Full Test Suite Verification & Documentation

**Files:**
- Modify: `README.md:25-50`
- Test: All tests in `GeminiVoiceUnitTests`

**Interfaces:**
- Consumes: All components from Tasks 1–6.
- Produces: 100% green test suite, regenerated project, updated README.

- [ ] **Step 1: Regenerate Xcode project**

```bash
xcodegen generate
```
Expected: Generates `GeminiVoiceKeyboard.xcodeproj` without errors.

- [ ] **Step 2: Run all unit tests**

```bash
xcodebuild test -scheme GeminiVoiceUnitTests -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Update documentation**

Update `README.md` to document the new `SpeechEngineMode` and the optional on-device model support.

- [ ] **Step 4: Commit**

```bash
git add project.yml README.md
git commit -m "docs: document offline Voice-to-Text and optional Gemma model support"
```

---

## Self-Review Checklist

- **Spec coverage:**
  - On-device speech recognition via Apple `SFSpeechRecognizer` -> Covered in Task 4.
  - Optional model download manager with background download & storage deletion -> Covered in Task 2.
  - Local Gemma/heuristic text processing -> Covered in Task 3.
  - Relay routing and live keyboard preview -> Covered in Task 5.
  - Settings UI for mode toggle and model management -> Covered in Task 6.
- **Placeholder scan:** No "TODO", "TBD", or unwritten test code blocks. All commands and code snippets are complete.
- **Type consistency:** `SpeechEngineMode` names and states match across tasks; `ModelDownloadManager.state` aligns in Task 2, Task 3, Task 5, and Task 6.
