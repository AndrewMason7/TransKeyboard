# Specification: Error Handling Deep Audit & Remediation

## Executive Summary

A comprehensive architectural and code-level audit was conducted across the Gemini Voice Keyboard codebase covering:
- **Audio Capture & AVFoundation Graph** (`App/Audio/`)
- **Relay Controller & Dictation Lifecycle** (`App/Relay/`)
- **Shared Relay Store & Cross-Process IPC** (`Shared/Relay/`, `KeyboardExtension/`)
- **Cloud & Streaming Services** (`App/Gemini/`)
- **On-Device Local AI & Transcription** (`App/LocalAI/`)
- **Persistence, Storage & Crash Recovery** (`App/Recovery/`, `App/Application/`)

The audit identified critical reliability risks including potential UI deadlocks from unbounded blocking `flock`, missing standard `AVAudioSession` interruption notifications (phone calls/Siri), unobserved connection failures during live streaming, swallowed file deletion and move collisions, and coarse/unhelpful error messaging for keyboard users.

---

## Detailed Audit Findings

### 1. Audio Capture Engine (`App/Audio/`)
- **Missing `AVAudioSession.interruptionNotification`**: The engine registers for `didBecomeInactiveNotification` and `resumptionRecommendationNotification`, but omits `AVAudioSession.interruptionNotification`. Incoming cellular calls, FaceTime, Siri invocations, or alarms trigger an interruption that is never caught, risking an inconsistent tap state or hanging audio engine graph.
- **Move Item Collision Data Loss**: When finalizing a recording in `AudioCaptureEngine+Recording.swift:149-155`, `FileManager.default.moveItem(at: url, to: finalizedURL)` fails if `finalizedURL` already exists. In the `catch` block, both `url` (the active recording) and `finalizedURL` (the previous recording) are deleted via `try? removeItem`. A request ID collision destroys both audio files.
- **Silent Converter Initialization Failure**: When `configureStreamingConverter` cannot find an output format or converter, it logs and sets `streamingConverter = nil`. When `beginSegment` is invoked with `audioChunkHandler != nil`, streaming fails immediately, but the capture engine continues running without switching modes.

### 2. Cross-Process IPC & Synchronization (`Shared/Relay/SharedRelayStore.swift`)
- **Unbounded Blocking `flock(LOCK_EX)` on Caller Threads**: In `withCommandLock`, `withResultLock`, and `withLaunchRequestLock`, if an exclusive lock is not immediately available, `flock(handle.fileDescriptor, LOCK_EX)` is called synchronously. If the holding process (main app or keyboard extension) is suspended or slow, the caller's main thread blocks unconditionally, directly risking iOS watchdog (0x8badf00d) process termination.
- **Remediation**: Implement bounded exponential backoff polling (`LOCK_EX | LOCK_NB`) with a 300ms deadline before failing gracefully.

### 3. Relay Controller & Dictation Management (`App/Relay/`)
- **Unobserved Early Live Connection Errors**: In `beginDictation`, `liveConnectionTask = Task { try await liveSession.connect(...) }` runs as an unobserved task. If WebSocket connection or authorization fails immediately, the error is suppressed until `finishDictationAndTranscribe` is awaited minutes later. During that entire time, the user believes live transcription is active while chunks are silently dropped or buffered up to the maximum cap.
- **Recoverable Recording State Desync on Background Task Expiration**: In `transcriptionBackgroundTimeExpired()`, `processingRecordingID` is reset to `nil` without notifying `recoveryStore.markFailed`. The recording in the store remains indefinitely marked as "Waiting for transcription" rather than "Processing timed out".
- **Local Transcription Failure Recovery Omission**: When local on-device transcription fails, the recording segment is staged into `recoveryStore`, but `recoveryStore.markFailed(id: ..., message: ...)` is never invoked, leaving the user with no explanation of why the recording was parked.
- **Silent Retry Rejections**: In `retryRecording()`, tapping "Retry" without a valid API key or with missing audio silently exits via `guard ... else { return }`, providing zero UI feedback to the user.

### 4. Cloud Services & Status Mapping (`App/Gemini/`, `App/Recovery/`)
- **Coarse Status Classification**: `RecoverableRecordingStatus.keyboardMessage(for:)` only differentiates `NSURLErrorDomain`. All API key errors (`GeminiTranscriptionError.missingAPIKey`), authentication errors (HTTP 401/403), and rate limit errors (HTTP 429) default to the generic `"Transcription failed — recording saved. Retry in Gemini Voice."`, concealing actionable remediation steps from the keyboard user.
- **Batch Client Network Blip Vulnerability**: `GeminiTranscriptionClient` retries HTTP 5xx and 429, but does not retry transient transport disconnects (`URLError.networkConnectionLost`, `URLError.timedOut`), immediately failing dictations on momentary packet loss.

### 5. On-Device Speech & Model Management (`App/LocalAI/`)
- **Untyped Generic `NSError`**: `LocalSpeechTranscriber` throws generic `NSError(domain: "LocalSpeechTranscriber", code: 1, ...)` rather than a structured `LocalizedError` enum, causing system error strings like `"The operation couldn't be completed. (LocalSpeechTranscriber error 1.)"`.
- **Download Move Validation**: In `ModelDownloadManager`, disk capacity is not pre-checked before moving the multi-gigabyte Gemma model, resulting in generic Cocoa error 512/640 on full devices.

---

## Remediation Objectives & Deliverables

1. Register and handle `AVAudioSession.interruptionNotification` with full `.began` and `.ended` (with `.shouldResume`) support.
2. Replace blocking `flock` in `SharedRelayStore` with bounded backoff lock acquisition.
3. Replace destructive move collisions with safe replacement or unique path generation in `AudioCaptureEngine`.
4. Monitor `liveConnectionTask` actively to fail fast or fall back immediately upon connection failure.
5. Record explicit failure messages in `RecoverableRecordingStore` whenever background tasks expire or local dictation fails.
6. Provide distinct, actionable keyboard messages for missing API keys, invalid keys, and rate limits.
7. Refactor `LocalSpeechTranscriber` to throw strongly-typed `LocalSpeechTranscriberError`.
