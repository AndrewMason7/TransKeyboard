import AVFoundation
import Combine
import Foundation
import Speech
import UIKit

extension RelayController {
  func cancelAutomaticReturnToKeyboard() {
    returnToKeyboardWorkItem?.cancel()
    returnToKeyboardWorkItem = nil
    returnToKeyboardGeneration += 1
    pendingHostReturn = nil
    hostReturnAttemptCount = 0
    systemNavigationReturnDeadline = nil
    systemNavigationReturnAccepted = false
  }

  func cancelDictation(message: String? = nil) {
    cancelAutomaticReturnToKeyboard()
    pendingAudioRecoveryError = nil
    maximumDurationWorkItem?.cancel()
    maximumDurationWorkItem = nil
    pendingFinishWorkItem?.cancel()
    pendingFinishWorkItem = nil
    let hadLiveStream = liveRequestID == activeRequestID
    if let activeRequestID {
      cancelLiveStream(matching: activeRequestID)
    }
    if isUsingLocalTranscriber {
      localTranscriber.cancel()
      isUsingLocalTranscriber = false
    }
    if let segment = activeLocalAudioSegment {
      try? FileManager.default.removeItem(at: segment.url)
      activeLocalAudioSegment = nil
    }
    capture.cancelSegment()
    audioLevel = 0
    activeRequestID = nil
    activeDictationAction = nil
    activeStartedAt = nil
    isKeyboardHandoffActive = false
    publish(
      .idle,
      message: message
        ?? (hadLiveStream
          ? "Live stream stopped and result discarded — ready"
          : "Dictation cancelled — ready")
    )
    markRelayActivityAndScheduleIdleShutdown()
  }

  func cancelTranscription(requestID: String) {
    guard status == .transcribing,
      processingRequestID == requestID
    else { return }

    transcriptionGeneration += 1
    transcriptionTask?.cancel()
    transcriptionTask = nil
    cancelLiveStream(matching: requestID)
    if isUsingLocalTranscriber {
      localTranscriber.cancel()
      isUsingLocalTranscriber = false
    }
    if let segment = activeLocalAudioSegment {
      try? FileManager.default.removeItem(at: segment.url)
      activeLocalAudioSegment = nil
    }

    let recordingID = processingRecordingID
    processingRequestID = nil
    processingRecordingID = nil
    endTranscriptionBackgroundTaskIfNeeded()

    if let recordingID {
      do {
        try recoveryStore.remove(id: recordingID)
      } catch {
        recoveryStore.markFailed(
          id: recordingID,
          message: "Processing stopped, but the saved recording could not be deleted: \(error.localizedDescription)"
        )
        refreshRecoverableRecordings()
        publish(
          .error,
          message: "Processing stopped, but the saved recording could not be deleted"
        )
        markRelayActivityAndScheduleIdleShutdown()
        return
      }
    }
    refreshRecoverableRecordings()

    if applyPendingAudioRecoveryFailureIfNeeded() {
      return
    }
    publish(.idle, message: "Processing cancelled — ready")
    markRelayActivityAndScheduleIdleShutdown()
  }

  func finishDictationAndTranscribe(requestID: String) {
    markRelayActivityAndSuspendIdleShutdown()
    pendingFinishWorkItem?.cancel()
    pendingFinishWorkItem = nil
    maximumDurationWorkItem?.cancel()
    maximumDurationWorkItem = nil

    let segment: CapturedAudioSegment
    let action = activeDictationAction ?? .transcribe
    let liveSession = liveRequestID == requestID ? activeLiveSession : nil
    let connectionTask = liveRequestID == requestID ? liveConnectionTask : nil
    do {
      segment = try capture.endSegment()
      audioLevel = 0
    } catch {
      cancelLiveStream(matching: requestID)
      activeRequestID = nil
      activeDictationAction = nil
      activeStartedAt = nil
      publish(
        .error,
        message: error.localizedDescription,
        activeRequestID: requestID,
        activeDictationAction: action
      )
      markRelayActivityAndScheduleIdleShutdown()
      return
    }

    activeRequestID = nil
    activeDictationAction = nil
    activeStartedAt = nil
    isKeyboardHandoffActive = false

    if isUsingLocalTranscriber {
      activeLocalAudioSegment = segment
      processingRequestID = requestID
      transcriptionGeneration += 1
      let processingMessage = action == .translate
        ? "Finalizing on-device translation…"
        : "Finalizing on-device transcript…"
      publish(
        .transcribing,
        message: processingMessage,
        activeRequestID: requestID,
        activeDictationAction: action
      )
      beginTranscriptionBackgroundTaskIfNeeded()
      localTranscriber.finish()
      return
    }

    let processingMessage: String
    if liveSession != nil {
      processingMessage =
        action == .translate
        ? "Finalizing live translation…"
        : "Finalizing live transcript…"
    } else {
      processingMessage =
        action == .translate
        ? "Gemini is transcribing, then translating…"
        : "Gemini is transcribing…"
    }
    publish(
      .transcribing,
      message: processingMessage,
      activeRequestID: requestID,
      activeDictationAction: action
    )
    beginTranscriptionBackgroundTaskIfNeeded()

    let apiKey = configuration.apiKey
    let translationTarget = configuration.translationTarget
    let recoverableRecording: RecoverableRecording
    do {
      recoverableRecording = try recoveryStore.stage(
        segment,
        action: action,
        translationTargetCode: translationTarget.code
      )
    } catch {
      cancelLiveStream(matching: requestID)
      publish(
        .error,
        message: "Recording saved, but retry metadata failed: \(error.localizedDescription)",
        activeRequestID: requestID,
        activeDictationAction: action
      )
      markRelayActivityAndScheduleIdleShutdown()
      endTranscriptionBackgroundTaskIfNeeded()
      return
    }
    refreshRecoverableRecordings()
    processingRequestID = requestID
    processingRecordingID = recoverableRecording.id
    transcriptionGeneration += 1
    let generation = transcriptionGeneration
    transcriptionTask?.cancel()
    transcriptionTask = Task { [weak self] in
      guard let self else { return }
      defer {
        if generation == transcriptionGeneration {
          cancelLiveStream(matching: requestID)
          transcriptionTask = nil
          processingRequestID = nil
          processingRecordingID = nil
          endTranscriptionBackgroundTaskIfNeeded()
        }
      }

      do {
        try Task.checkCancellation()
        let outputText: String
        let usedLiveStream: Bool
        if let liveSession, let connectionTask {
          do {
            try await connectionTask.value
            try Task.checkCancellation()
            outputText = try await liveSession.finish()
            usedLiveStream = true
          } catch is CancellationError {
            throw CancellationError()
          } catch {
            NSLog(
              "LIVE_STREAM_FALLBACK request=%@ reason=%@",
              requestID,
              Self.safeErrorSummary(error)
            )
            if self.configuration.speechEngineMode == .autoFallback {
              do {
                let localRaw = try await self.localFallbackResult(
                  from: segment.url,
                  action: action,
                  translationTarget: translationTarget
                )
                if action == .translate {
                  outputText = await self.localTextProcessor.translateText(localRaw, targetLanguageCode: translationTarget.code)
                } else {
                  outputText = await self.localTextProcessor.formatTranscript(localRaw)
                }
                usedLiveStream = false
              } catch {
                outputText = try await fallbackResult(
                  from: segment,
                  action: action,
                  translationTarget: translationTarget,
                  apiKey: apiKey
                )
                usedLiveStream = false
              }
            } else {
              outputText = try await fallbackResult(
                from: segment,
                action: action,
                translationTarget: translationTarget,
                apiKey: apiKey
              )
              usedLiveStream = false
            }
          }
        } else {
          outputText = try await fallbackResult(
            from: segment,
            action: action,
            translationTarget: translationTarget,
            apiKey: apiKey
          )
          usedLiveStream = false
        }
        try Task.checkCancellation()
        guard generation == transcriptionGeneration, isRelayRunning else {
          recoveryStore.markFailed(
            id: recoverableRecording.id,
            message: "Processing was interrupted; the recording is still saved"
          )
          refreshRecoverableRecordings()
          return
        }

        try addToHistory(outputText)
        store.publishTranscript(
          outputText,
          requestID: requestID,
          kind: .dictation
        )
        do {
          try recoveryStore.remove(id: recoverableRecording.id)
        } catch {
          recoveryStore.markTranscriptSaved(
            id: recoverableRecording.id,
            cleanupError: "Transcript saved. Audio cleanup failed: \(error.localizedDescription)"
          )
          refreshRecoverableRecordings()
          publish(.error, message: error.localizedDescription)
          markRelayActivityAndScheduleIdleShutdown()
          return
        }
        refreshRecoverableRecordings()
        if applyPendingAudioRecoveryFailureIfNeeded() {
          return
        }
        let completionMessage: String
        if usedLiveStream {
          completionMessage =
            action == .translate
            ? "Live translation inserted — ready"
            : "Live transcript inserted — ready"
        } else {
          completionMessage =
            action == .translate
            ? "Translated to \(translationTarget.name) and inserted — ready"
            : "Inserted — ready for the next dictation"
        }
        publish(.idle, message: completionMessage)
        markRelayActivityAndScheduleIdleShutdown()
      } catch is CancellationError {
        recoveryStore.markFailed(
          id: recoverableRecording.id,
          message: "Processing paused; the recording is still saved"
        )
        refreshRecoverableRecordings()
        return
      } catch {
        recoveryStore.markFailed(
          id: recoverableRecording.id,
          message: error.localizedDescription
        )
        refreshRecoverableRecordings()
        guard generation == transcriptionGeneration, isRelayRunning else { return }
        if applyPendingAudioRecoveryFailureIfNeeded() {
          return
        }
        publish(
          .error,
          message: RecoverableRecordingStatus.keyboardMessage(for: error),
          activeRequestID: requestID,
          activeDictationAction: action
        )
        markRelayActivityAndScheduleIdleShutdown()
      }
    }
  }

  func fallbackResult(
    from segment: CapturedAudioSegment,
    action: RelayDictationAction,
    translationTarget: TranslationLanguage,
    apiKey: String
  ) async throws -> String {
    try Task.checkCancellation()
    return try await fallbackResult(
      from: segment.url,
      action: action,
      translationTarget: translationTarget,
      apiKey: apiKey
    )
  }

  func fallbackResult(
    from segmentURL: URL,
    action: RelayDictationAction,
    translationTarget: TranslationLanguage,
    apiKey: String
  ) async throws -> String {
    try Task.checkCancellation()
    let audioData = try await Task.detached(priority: .userInitiated) {
      try Data(contentsOf: segmentURL)
    }.value
    try Task.checkCancellation()
    let sourceText = try await client.transcribe(
      audioData: audioData,
      apiKey: apiKey,
      model: configuration.transcriptionModel
    )
    guard action == .translate else { return sourceText }
    return try await client.translate(
      text: sourceText,
      targetLanguage: translationTarget,
      apiKey: apiKey,
      model: configuration.translationModel
    )
  }

  func publishLivePreview(
    _ text: String,
    requestID: String,
    action: RelayDictationAction
  ) {
    guard status == .recording, activeRequestID == requestID else { return }
    let now = Date()
    guard now.timeIntervalSince(lastLivePreviewAt) >= 0.35 else { return }
    let cleaned = TranscriptFormatter.cleaned(text)
    guard !cleaned.isEmpty else { return }
    lastLivePreviewAt = now

    let preview = String(cleaned.prefix(100))
    let label = action == .translate ? "Live translation" : "Live transcript"
    let message = "\(label): \(preview)"
    setLocalStatus(.recording, message: message)
    store.publishStatus(
      .recording,
      message: message,
      activeRequestID: requestID,
      activeDictationAction: action,
      recordingStartedAt: activeStartedAt
    )
  }

  func cancelLiveStream(matching requestID: String? = nil) {
    if let requestID, liveRequestID != requestID { return }
    liveConnectionTask?.cancel()
    liveConnectionTask = nil
    if let activeLiveSession {
      Task { await activeLiveSession.cancel() }
    }
    activeLiveSession = nil
    liveRequestID = nil
  }

  static func safeErrorSummary(_ error: Error) -> String {
    switch error {
    case let liveError as GeminiLiveSpeechError:
      return liveError.localizedDescription
    default:
      return "stream connection failed"
    }
  }

  func localFallbackResult(
    from url: URL,
    action: RelayDictationAction,
    translationTarget: TranslationLanguage
  ) async throws -> String {
    let recognizer = SFSpeechRecognizer(locale: Locale.current)
    guard let recognizer, recognizer.isAvailable else {
      throw AudioCaptureError.sessionUnavailable("Local speech recognizer unavailable")
    }
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.taskHint = .dictation
    request.addsPunctuation = true
    if recognizer.supportsOnDeviceRecognition {
      request.requiresOnDeviceRecognition = true
    }

    final class RecognitionState: @unchecked Sendable {
      var task: SFSpeechRecognitionTask?
      var didResume = false
      let lock = NSLock()
    }
    let state = RecognitionState()

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let task = recognizer.recognitionTask(with: request) { result, error in
          state.lock.lock()
          defer { state.lock.unlock() }
          guard !state.didResume else { return }
          if let result, result.isFinal {
            state.didResume = true
            continuation.resume(returning: result.bestTranscription.formattedString)
          } else if let error {
            state.didResume = true
            continuation.resume(throwing: error)
          }
        }
        state.lock.lock()
        state.task = task
        if state.didResume {
          task.cancel()
        }
        state.lock.unlock()
      }
    } onCancel: {
      state.lock.lock()
      state.task?.cancel()
      state.lock.unlock()
    }
  }

  func handleLocalTranscriptionResult(
    _ result: Result<String, Error>,
    requestID: String,
    action: RelayDictationAction
  ) {
    guard activeRequestID == requestID || processingRequestID == requestID else {
      NSLog("LOCAL_TRANSCRIPTION_DROPPED_STALE request=%@", requestID)
      return
    }
    isUsingLocalTranscriber = false
    switch result {
    case .success(let rawText):
      Task {
        guard self.processingRequestID == requestID || self.activeRequestID == requestID else { return }
        let processedText: String
        if action == .translate {
          processedText = await localTextProcessor.translateText(rawText, targetLanguageCode: configuration.translationTarget.code)
        } else {
          processedText = await localTextProcessor.formatTranscript(rawText)
        }
        guard self.processingRequestID == requestID || self.activeRequestID == requestID else { return }
        self.finalizeLocalTranscription(processedText, requestID: requestID, action: action)
      }
    case .failure(let error):
      guard self.processingRequestID == requestID || self.activeRequestID == requestID else { return }
      self.processingRequestID = nil
      self.endTranscriptionBackgroundTaskIfNeeded()
      if let segment = self.activeLocalAudioSegment {
        do {
          _ = try self.recoveryStore.stage(
            segment,
            action: action,
            translationTargetCode: self.configuration.translationTarget.code
          )
          self.refreshRecoverableRecordings()
        } catch {
          try? FileManager.default.removeItem(at: segment.url)
        }
        self.activeLocalAudioSegment = nil
      }
      self.publish(.error, message: error.localizedDescription, activeRequestID: requestID, activeDictationAction: action)
      self.markRelayActivityAndScheduleIdleShutdown()
    }
  }

  func finalizeLocalTranscription(
    _ text: String,
    requestID: String,
    action: RelayDictationAction
  ) {
    if let segment = activeLocalAudioSegment {
      try? FileManager.default.removeItem(at: segment.url)
      activeLocalAudioSegment = nil
    }
    processingRequestID = nil
    endTranscriptionBackgroundTaskIfNeeded()
    do {
      try addToHistory(text)
      store.publishTranscript(
        text,
        requestID: requestID,
        kind: .dictation
      )
      let completionMessage = action == .translate
        ? "On-device translation inserted — ready"
        : "On-device transcript inserted — ready"
      publish(.idle, message: completionMessage)
      markRelayActivityAndScheduleIdleShutdown()
    } catch {
      publish(.error, message: error.localizedDescription)
      markRelayActivityAndScheduleIdleShutdown()
    }
  }
}
