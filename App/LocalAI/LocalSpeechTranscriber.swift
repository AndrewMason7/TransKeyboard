import Foundation
import Speech
import AVFoundation

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
  private var latestHypothesis: String = ""
  private var didComplete: Bool = false
  private var finishSafetyWorkItem: DispatchWorkItem?
  private var activeCompletionHandler: (@Sendable (Result<String, Error>) -> Void)?

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
      throw NSError(
        domain: "LocalSpeechTranscriber",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"]
      )
    }

    cancel()
    isRunning = true
    didComplete = false
    latestHypothesis = ""
    activeCompletionHandler = completionHandler

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
          let text = result.bestTranscription.formattedString
          self.latestHypothesis = text
          progressHandler(text)
          if result.isFinal {
            self.completeWithSuccess(text)
          }
        } else if let error {
          if !self.latestHypothesis.isEmpty {
            self.completeWithSuccess(self.latestHypothesis)
          } else {
            self.completeWithError(error)
          }
        }
      }
    }
  }

  private func completeWithSuccess(_ text: String) {
    guard !didComplete else { return }
    didComplete = true
    isRunning = false
    finishSafetyWorkItem?.cancel()
    finishSafetyWorkItem = nil
    recognitionRequest = nil
    recognitionTask = nil
    let handler = activeCompletionHandler
    activeCompletionHandler = nil
    handler?(.success(text))
  }

  private func completeWithError(_ error: Error) {
    guard !didComplete else { return }
    didComplete = true
    isRunning = false
    finishSafetyWorkItem?.cancel()
    finishSafetyWorkItem = nil
    recognitionRequest = nil
    recognitionTask = nil
    let handler = activeCompletionHandler
    activeCompletionHandler = nil
    handler?(.failure(error))
  }

  public func appendAudioData(_ data: Data) {
    guard isRunning, let request = recognitionRequest, let format = Self.pcm16Format else { return }
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
    guard isRunning else { return }
    recognitionRequest?.endAudio()
    isRunning = false
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
    isRunning = false
    didComplete = true
  }
}
