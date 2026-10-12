import Foundation
import Speech
import AVFoundation

public enum LocalSpeechTranscriberError: LocalizedError, Equatable {
  case recognizerUnavailable
  case permissionDenied
  case audioInputInvalid
  case recognitionFailed(String)
  case timedOut

  public var errorDescription: String? {
    switch self {
    case .recognizerUnavailable:
      return "On-device speech recognizer is unavailable for the current language."
    case .permissionDenied:
      return "Speech recognition permission was not granted."
    case .audioInputInvalid:
      return "The microphone audio format is not supported for on-device recognition."
    case .recognitionFailed(let details):
      return "On-device speech recognition failed: \(details)"
    case .timedOut:
      return "Speech recognition timed out while finalizing."
    }
  }
}

@MainActor
public final class LocalSpeechTranscriber: NSObject, Sendable {
  public static let pcm16Format = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 16000,
    channels: 1,
    interleaved: false
  )

  public var isOnDeviceRecognitionAvailable: Bool {
    recognizer?.supportsOnDeviceRecognition ?? false
  }

  public private(set) var isRunning: Bool = false
  public var requiresOnDeviceRecognition: Bool = true

  private let locale: Locale
  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var accumulatedText: String = ""
  private var latestHypothesis: String = ""
  private var isFinishing: Bool = false
  private var hasCompletedSession: Bool = false
  private var finishSafetyWorkItem: DispatchWorkItem?
  private var activeProgressHandler: (@Sendable (String) -> Void)?
  private var activeCompletionHandler: (@Sendable (Result<String, Error>) -> Void)?
  private var consecutiveErrorCount: Int = 0
  private var taskGeneration: Int = 0

  nonisolated public static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
    SFSpeechRecognizer.authorizationStatus()
  }

  nonisolated public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { @Sendable status in
        continuation.resume(returning: status)
      }
    }
  }

  nonisolated public static func ensureAuthorized() async -> Bool {
    let current = authorizationStatus
    if current == .authorized { return true }
    if current == .notDetermined {
      let status = await requestAuthorization()
      return status == .authorized
    }
    return false
  }

  public init(locale: Locale = Locale.current) {
    self.locale = locale
    self.recognizer = SFSpeechRecognizer(locale: locale)
    self.recognizer?.defaultTaskHint = .dictation
    super.init()
  }

  public func start(
    progressHandler: @escaping @Sendable (String) -> Void,
    completionHandler: @escaping @Sendable (Result<String, Error>) -> Void
  ) throws {
    guard let recognizer, recognizer.isAvailable else {
      throw LocalSpeechTranscriberError.recognizerUnavailable
    }

    cancel()
    isRunning = true
    isFinishing = false
    hasCompletedSession = false
    accumulatedText = ""
    latestHypothesis = ""
    consecutiveErrorCount = 0
    activeProgressHandler = progressHandler
    activeCompletionHandler = completionHandler

    try startRecognitionTask()
  }

  private static let maxFatalConsecutiveErrors = 5

  static func combinedText(accumulatedText: String, segment: String) -> String {
    let cleanSegment = TranscriptFormatter.cleaned(segment)
    let cleanAccumulated = TranscriptFormatter.cleaned(accumulatedText)
    if cleanAccumulated.isEmpty { return cleanSegment }
    guard !cleanSegment.isEmpty else { return cleanAccumulated }

    if cleanAccumulated == cleanSegment {
      return cleanAccumulated
    }

    // Check if segment is an exact continuation or superset on word boundaries
    let prefixesToCheck = [
      cleanAccumulated,
      cleanAccumulated.trimmingCharacters(in: CharacterSet(charactersIn: ".?!,:;-— \n\t")),
    ]
    for prefix in prefixesToCheck where !prefix.isEmpty {
      if cleanSegment.hasPrefix(prefix) {
        if cleanSegment.count == prefix.count {
          return cleanSegment
        }
        let boundaryIndex = cleanSegment.index(cleanSegment.startIndex, offsetBy: prefix.count)
        let boundaryChar = cleanSegment[boundaryIndex]
        if boundaryChar.isWhitespace || boundaryChar.isPunctuation {
          return cleanSegment
        }
      }
    }

    let insertion = TranscriptFormatter.textForInsertion(cleanSegment, contextBefore: cleanAccumulated)
    return cleanAccumulated + insertion
  }

  private func combinedText(segment: String) -> String {
    Self.combinedText(accumulatedText: accumulatedText, segment: segment)
  }

  private func accumulate(_ segment: String) {
    let merged = combinedText(segment: segment)
    accumulatedText = merged
  }

  private func startRecognitionTask() throws {
    guard let recognizer, recognizer.isAvailable else {
      throw LocalSpeechTranscriberError.recognizerUnavailable
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.taskHint = .dictation
    request.addsPunctuation = true
    request.shouldReportPartialResults = true
    if requiresOnDeviceRecognition && recognizer.supportsOnDeviceRecognition {
      request.requiresOnDeviceRecognition = true
    }
    self.recognitionRequest = request

    taskGeneration += 1
    let currentGeneration = taskGeneration
    self.recognitionTask = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
      let transcriptionText = result?.bestTranscription.formattedString
      let isFinal = result?.isFinal ?? false
      let taskError = error

      Task { @MainActor [weak self] in
        guard let self, !self.hasCompletedSession, self.taskGeneration == currentGeneration else { return }
        if let transcriptionText {
          self.consecutiveErrorCount = 0
          let fullText = self.combinedText(segment: transcriptionText)
          self.latestHypothesis = fullText
          self.activeProgressHandler?(fullText)

          if isFinal {
            if self.isFinishing {
              self.completeWithSuccess(fullText)
            } else {
              self.accumulatedText = fullText
              self.restartRecognitionTask()
            }
          }
        } else if let taskError {
          if self.isFinishing {
            if !self.latestHypothesis.isEmpty {
              self.completeWithSuccess(self.latestHypothesis)
            } else {
              self.completeWithError(taskError)
            }
          } else {
            // Silence timeout or pause occurred during continuous recording.
            // Durably commit any recognized hypothesis before restarting the task.
            if !self.latestHypothesis.isEmpty {
              self.accumulatedText = self.latestHypothesis
            }

            let nsError = taskError as NSError
            let isSilenceTimeout =
              (nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 203 || nsError.code == 1110))
              || (nsError.domain == "kLSRErrorDomain" && (nsError.code == 201 || nsError.code == 102))

            // Expected pauses should not count toward fatal hardware/permission tripwire
            if !isSilenceTimeout {
              self.consecutiveErrorCount += 1
            }

            if self.consecutiveErrorCount > Self.maxFatalConsecutiveErrors {
              if !self.latestHypothesis.isEmpty {
                self.completeWithSuccess(self.latestHypothesis)
              } else {
                self.completeWithError(taskError)
              }
            } else {
              self.restartRecognitionTask()
            }
          }
        }
      }
    }
  }

  private func restartRecognitionTask() {
    guard isRunning, !isFinishing, !hasCompletedSession else { return }
    taskGeneration += 1
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    do {
      try startRecognitionTask()
    } catch {
      if !latestHypothesis.isEmpty {
        completeWithSuccess(latestHypothesis)
      } else {
        completeWithError(error)
      }
    }
  }

  // FIX #E2.1 (per Natasha): Single-exit completion ensures exactly-once semantics
  private func completeWithSuccess(_ text: String) {
    guard !hasCompletedSession else { return }
    hasCompletedSession = true
    cleanupActiveSession()

    let handler = activeCompletionHandler
    activeCompletionHandler = nil
    activeProgressHandler = nil
    handler?(.success(text))
  }

  private func completeWithError(_ error: Error) {
    guard !hasCompletedSession else { return }
    hasCompletedSession = true
    cleanupActiveSession()

    let handler = activeCompletionHandler
    activeCompletionHandler = nil
    activeProgressHandler = nil
    handler?(.failure(error))
  }

  private func cleanupActiveSession() {
    isRunning = false
    isFinishing = false
    finishSafetyWorkItem?.cancel()
    finishSafetyWorkItem = nil
    recognitionRequest = nil
    recognitionTask?.cancel()
    recognitionTask = nil
  }

  public func appendAudioData(_ data: Data) {
    guard isRunning, !isFinishing, let request = recognitionRequest, let format = Self.pcm16Format else { return }
    let frameCount = UInt32(data.count / MemoryLayout<Int16>.size)
    guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

    buffer.frameLength = frameCount
    let bytesToCopy = Int(frameCount) * MemoryLayout<Int16>.size
    data.withUnsafeBytes { rawBuffer in
      if let baseAddress = rawBuffer.baseAddress, let channel = buffer.int16ChannelData?[0] {
        memcpy(channel, baseAddress, bytesToCopy)
      }
    }
    request.append(buffer)
  }

  public func finish() {
    guard isRunning, !isFinishing else { return }
    isFinishing = true
    isRunning = false
    recognitionRequest?.endAudio()
    finishSafetyWorkItem?.cancel()

    // FIX #E2.1 & #Maya.1: Idempotent guard prevents timeout from colliding with final chunk
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, !self.hasCompletedSession else { return }
      if !self.latestHypothesis.isEmpty {
        self.completeWithSuccess(self.latestHypothesis)
      } else {
        self.completeWithError(LocalSpeechTranscriberError.timedOut)
      }
    }
    finishSafetyWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
  }

  public func cancel() {
    finishSafetyWorkItem?.cancel()
    finishSafetyWorkItem = nil
    taskGeneration += 1
    hasCompletedSession = true
    cleanupActiveSession()

    activeCompletionHandler = nil
    activeProgressHandler = nil
    accumulatedText = ""
    latestHypothesis = ""
    consecutiveErrorCount = 0
  }
}
