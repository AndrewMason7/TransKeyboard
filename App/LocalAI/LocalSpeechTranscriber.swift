import Foundation
import Speech
import AVFoundation

public enum LocalSpeechTranscriberError: LocalizedError, Equatable {
  case recognizerUnavailable
  case permissionDenied
  case audioInputInvalid
  case recognitionFailed(String)

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

  private let locale: Locale
  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var accumulatedText: String = ""
  private var latestHypothesis: String = ""
  private var isFinishing: Bool = false
  private var didComplete: Bool = false
  private var finishSafetyWorkItem: DispatchWorkItem?
  private var activeProgressHandler: (@Sendable (String) -> Void)?
  private var activeCompletionHandler: (@Sendable (Result<String, Error>) -> Void)?
  private var consecutiveErrorCount: Int = 0

  public static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
    SFSpeechRecognizer.authorizationStatus()
  }

  public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
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
    didComplete = false
    accumulatedText = ""
    latestHypothesis = ""
    consecutiveErrorCount = 0
    activeProgressHandler = progressHandler
    activeCompletionHandler = completionHandler

    try startRecognitionTask()
  }

  private func combinedText(segment: String) -> String {
    let cleanSegment = TranscriptFormatter.cleaned(segment)
    let cleanAccumulated = TranscriptFormatter.cleaned(accumulatedText)
    if cleanAccumulated.isEmpty { return cleanSegment }
    guard !cleanSegment.isEmpty else { return cleanAccumulated }
    let insertion = TranscriptFormatter.textForInsertion(cleanSegment, contextBefore: cleanAccumulated)
    return cleanAccumulated + insertion
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
    if recognizer.supportsOnDeviceRecognition {
      request.requiresOnDeviceRecognition = true
    }
    self.recognitionRequest = request

    self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      Task { @MainActor [weak self] in
        guard let self, !self.didComplete else { return }
        if let result {
          self.consecutiveErrorCount = 0
          let segmentText = result.bestTranscription.formattedString
          let fullText = self.combinedText(segment: segmentText)
          self.latestHypothesis = fullText
          self.activeProgressHandler?(fullText)

          if result.isFinal {
            if self.isFinishing {
              self.completeWithSuccess(fullText)
            } else {
              self.accumulate(segmentText)
              self.restartRecognitionTask()
            }
          }
        } else if let error {
          if self.isFinishing {
            if !self.latestHypothesis.isEmpty {
              self.completeWithSuccess(self.latestHypothesis)
            } else {
              self.completeWithError(error)
            }
          } else {
            self.consecutiveErrorCount += 1
            if self.consecutiveErrorCount > 3 {
              if !self.latestHypothesis.isEmpty {
                self.completeWithSuccess(self.latestHypothesis)
              } else {
                self.completeWithError(error)
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
    guard isRunning, !isFinishing, !didComplete else { return }
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

  private func completeWithSuccess(_ text: String) {
    guard !didComplete else { return }
    didComplete = true
    isRunning = false
    isFinishing = false
    finishSafetyWorkItem?.cancel()
    finishSafetyWorkItem = nil
    recognitionRequest = nil
    recognitionTask = nil
    let handler = activeCompletionHandler
    activeCompletionHandler = nil
    activeProgressHandler = nil
    handler?(.success(text))
  }

  private func completeWithError(_ error: Error) {
    guard !didComplete else { return }
    didComplete = true
    isRunning = false
    isFinishing = false
    finishSafetyWorkItem?.cancel()
    finishSafetyWorkItem = nil
    recognitionRequest = nil
    recognitionTask = nil
    let handler = activeCompletionHandler
    activeCompletionHandler = nil
    activeProgressHandler = nil
    handler?(.failure(error))
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
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, !self.didComplete else { return }
      if !self.latestHypothesis.isEmpty {
        self.completeWithSuccess(self.latestHypothesis)
      } else {
        self.completeWithError(
          NSError(
            domain: "LocalSpeechTranscriber",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Speech recognition timed out while finalizing."]
          )
        )
      }
    }
    finishSafetyWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
  }

  public func cancel() {
    finishSafetyWorkItem?.cancel()
    finishSafetyWorkItem = nil
    recognitionTask?.cancel()
    recognitionRequest?.endAudio()
    recognitionTask = nil
    recognitionRequest = nil
    activeCompletionHandler = nil
    activeProgressHandler = nil
    isRunning = false
    isFinishing = false
    didComplete = true
    accumulatedText = ""
    latestHypothesis = ""
    consecutiveErrorCount = 0
  }
}
