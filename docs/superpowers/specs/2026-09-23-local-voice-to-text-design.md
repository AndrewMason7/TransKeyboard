# Design Spec: Local Voice-to-Text with Optional Model Download

## 1. Overview
This specification defines the architecture, components, and data flow for adding offline on-device Voice-to-Text (ASR) with an optional on-demand local Gemma model to the Gemini Voice Keyboard iOS application.

## 2. Goals & Non-Goals
### Goals
- Support 100% offline speech recognition in the keyboard without requiring cloud connectivity.
- Provide a zero-download baseline using Apple's built-in on-device `SFSpeechRecognizer` (`requiresOnDeviceRecognition = true`).
- Provide an optional, user-initiated on-demand model download manager for local Gemma weights.
- When Gemma weights are present, utilize local Gemma for contextual speech cleanup, punctuation, formatting, and offline language translation.
- When Gemma weights are absent, fallback gracefully to raw ASR output with heuristic formatting so the user is never blocked from offline transcription.
- Seamlessly stream partial results into `SharedRelayStore` so the keyboard extension UI displays live interim words identically to Gemini Live.

### Non-Goals
- Running local models inside `KeyboardExtension` (memory limit violation; must run in containing app relay).
- Bundling gigabyte-scale model weights inside the App Store IPA binary.
- Replacing Gemini Live for users with active network who prefer cloud models.

## 3. System Architecture & Component Interactions

```text
KeyboardExtension (Process A)
  │  RelayCommand: .start, .stop, .cancel
  ▼
SharedRelayStore (IPC App Group)
  │
  ▼
RelayController (Process B)
  │
  ├─ [AudioCaptureEngine] captures 16 kHz PCM
  │
  ├─ Mode: .geminiLive ──> [GeminiLiveSpeechSession] (Cloud)
  │
  └─ Mode: .localOnDevice / .autoFallback
       ▼
     [LocalSpeechTranscriber] (SFSpeechRecognizer on-device)
       │  Streams partial hypothesis
       ▼
     SharedRelayStore.livePreviewText (Keyboard UI updates in real-time)
       │
     (On Stop/Finish)
       ▼
     [LocalTextProcessor]
       ├─ If ModelDownloadManager.isReady:
       │    Local Gemma Model (Punctuation, formatting, offline translation)
       └─ Else:
            Heuristic Formatter (Standard punctuation & whitespace)
       │
       ▼
     SharedRelayStore.commitResult()
       │
       ▼
     UITextDocumentProxy.insertText()
```

## 4. Components & Interfaces

### 4.1 SpeechEngineMode
Defined in `App/Application/SpeechEngineMode.swift`:
```swift
public enum SpeechEngineMode: String, CaseIterable, Identifiable, Codable {
  case geminiLive = "geminiLive"
  case localOnDevice = "localOnDevice"
  case autoFallback = "autoFallback"

  public var id: String { rawValue }
  public var displayName: String { ... }
  public var subtitle: String { ... }
}
```

### 4.2 ModelDownloadManager
Observable manager in `App/LocalAI/ModelDownloadManager.swift`:
```swift
@MainActor
public final class ModelDownloadManager: ObservableObject {
  public enum DownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case ready(fileSize: Int64, fileURL: URL)
    case failed(String)
  }

  @Published public private(set) var state: DownloadState
  public var isReady: Bool { ... }

  public func startDownload(from url: URL? = nil)
  public func cancelDownload()
  public func deleteModel()
}
```

### 4.3 LocalTextProcessing
Interface in `App/LocalAI/LocalTextProcessor.swift`:
```swift
public protocol LocalTextProcessing: Sendable {
  func formatTranscript(_ rawText: String) async -> String
  func translateText(_ rawText: String, targetLanguageCode: String) async -> String
}
```

### 4.4 LocalSpeechTranscribing
Interface in `App/LocalAI/LocalSpeechTranscriber.swift`:
```swift
public protocol LocalSpeechTranscribing: AnyObject, Sendable {
  func start(
    progressHandler: @escaping @Sendable (String) -> Void,
    completionHandler: @escaping @Sendable (Result<String, Error>) -> Void
  ) throws
  func appendAudioData(_ data: Data)
  func finish()
  func cancel()
}
```

## 5. Storage & Safety Invariants
- Downloaded models are stored in `Application Support/LocalModels/gemma-2b-q4.bin` (excluded from iCloud backup).
- Model deletions wipe file handles and notify the UI immediately.
- In-flight background downloads survive temporary app backgrounding via `URLSessionConfiguration.background`.
- Relay sequence monotonic increment rules are preserved.
