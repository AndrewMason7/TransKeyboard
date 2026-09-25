import AVFoundation
import Darwin
import Foundation
import ObjectiveC
import Observation
import UIKit

enum RelayIdleShutdownPolicy {
  static let timeout: TimeInterval = 2 * 60

  static func canStop(
    relayIsRunning: Bool,
    operationIsBusy: Bool,
    hasPendingHandoff: Bool,
    hasPendingCommand: Bool
  ) -> Bool {
    relayIsRunning
      && !operationIsBusy
      && !hasPendingHandoff
      && !hasPendingCommand
  }
}

@Observable
@MainActor
final class RelayController {
  static let maximumDictationDuration: TimeInterval = 5 * 60

  struct PendingHostReturn: Equatable {
    let requestID: String
    let bundleIdentifier: String?
  }

  #if GEMINI_PERSONAL_DEVICE
    struct HostReactivationResult {
      let accepted: Bool
      let stage: String
    }

    // Keep the image resident for the process lifetime. Releasing this handle
    // immediately after invoking LaunchServices adds an avoidable loader race
    // while SpringBoard is still acting on the asynchronous activation request.
    static let coreServicesFrameworkHandle = dlopen(
      "/System/Library/Frameworks/CoreServices.framework/CoreServices",
      RTLD_LAZY | RTLD_LOCAL
    )
  #endif

  var isRelayRunning = false
  var isRelayStarting = false
  var status: RelayStatus = .offline
  var statusMessage = "Relay is offline"
  var history: [TranscriptHistoryItem] = []
  var recoverableRecordings: [RecoverableRecording] = []
  var retryingRecordingID: UUID?
  var activeStartedAt: Date?
  var isImagePickerPresented = false
  var imagePickerSource: UIImagePickerController.SourceType = .camera
  var isProcessingImage = false
  var ocrMessage = "Capture a page, sign, receipt, or screen"
  var isKeyboardHandoffActive = false
  var requiresManualKeyboardReturn = false
  var audioLevel: Double = 0

  @ObservationIgnored let configuration: AppConfiguration
  @ObservationIgnored let store: SharedRelayStore
  @ObservationIgnored let capture: AudioCaptureEngine
  @ObservationIgnored let client: GeminiTranscriptionClient
  @ObservationIgnored let recoveryStore: RecoverableRecordingStore
  @ObservationIgnored let historyStore: TranscriptHistoryStore
  @ObservationIgnored let liveActivity = VoiceRelayLiveActivityController()
  @ObservationIgnored let pollingQueue = DispatchQueue(label: "GeminiVoice.relay-polling")

  @ObservationIgnored var pollTimer: DispatchSourceTimer?
  @ObservationIgnored var idleShutdownWorkItem: DispatchWorkItem?
  @ObservationIgnored var lastHandledSequence = 0
  @ObservationIgnored var heartbeatTick = 0
  @ObservationIgnored var activeRequestID: String?
  @ObservationIgnored var activeDictationAction: RelayDictationAction?
  @ObservationIgnored var maximumDurationWorkItem: DispatchWorkItem?
  @ObservationIgnored var pendingFinishWorkItem: DispatchWorkItem?
  @ObservationIgnored var returnToKeyboardWorkItem: DispatchWorkItem?
  @ObservationIgnored var returnToKeyboardGeneration = 0
  @ObservationIgnored var pendingHostReturn: PendingHostReturn?
  @ObservationIgnored var hostReturnAttemptCount = 0
  @ObservationIgnored var systemNavigationReturnDeadline: Date?
  @ObservationIgnored var systemNavigationReturnAccepted = false
  @ObservationIgnored var transcriptionBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
  @ObservationIgnored var ocrBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
  @ObservationIgnored var pendingOCRRequestID: String?
  @ObservationIgnored var pendingLaunchRequest: RelayLaunchRequest?
  @ObservationIgnored var relayStartupGeneration = 0
  @ObservationIgnored var transcriptionGeneration = 0
  @ObservationIgnored var transcriptionTask: Task<Void, Never>?
  @ObservationIgnored var processingRequestID: String?
  @ObservationIgnored var processingRecordingID: UUID?
  @ObservationIgnored var recoveryRetryTask: Task<Void, Never>?
  @ObservationIgnored var relaySessionID: String?
  @ObservationIgnored var liveRequestID: String?
  @ObservationIgnored var activeLiveSession: GeminiLiveSpeechSession?
  @ObservationIgnored var liveConnectionTask: Task<Void, Error>?
  @ObservationIgnored var lastLivePreviewAt = Date.distantPast
  @ObservationIgnored var pendingAudioRecoveryError: Error?

  @ObservationIgnored let modelDownloadManager: ModelDownloadManager
  @ObservationIgnored let localTextProcessor: LocalTextProcessor
  @ObservationIgnored let localTranscriber: LocalSpeechTranscriber
  @ObservationIgnored var isUsingLocalTranscriber = false
  @ObservationIgnored var activeLocalAudioSegment: CapturedAudioSegment?

  init(
    configuration: AppConfiguration,
    store: SharedRelayStore = SharedRelayStore(),
    capture: AudioCaptureEngine = AudioCaptureEngine(),
    client: GeminiTranscriptionClient = GeminiTranscriptionClient(),
    recoveryStore: RecoverableRecordingStore = RecoverableRecordingStore(),
    historyStore: TranscriptHistoryStore = TranscriptHistoryStore(),
    modelDownloadManager: ModelDownloadManager = ModelDownloadManager(),
    localTextProcessor: LocalTextProcessor? = nil,
    localTranscriber: LocalSpeechTranscriber = LocalSpeechTranscriber()
  ) {
    self.configuration = configuration
    self.store = store
    self.capture = capture
    self.client = client
    self.recoveryStore = recoveryStore
    self.historyStore = historyStore
    self.modelDownloadManager = modelDownloadManager
    self.localTextProcessor = localTextProcessor ?? LocalTextProcessor(modelDownloadManager: modelDownloadManager)
    self.localTranscriber = localTranscriber
    history = historyStore.items
    recoverableRecordings = recoveryStore.recordings

    capture.levelHandler = { [weak self] level in
      DispatchQueue.main.async { [weak self] in
        guard let self,
          self.status == .recording,
          let requestID = self.activeRequestID
        else { return }
        self.audioLevel = level
        self.store.publishAudioLevel(level, requestID: requestID)
      }
    }
  }

  func applicationDidBecomeActive() async {
    guard UIApplication.shared.applicationState == .active else { return }
    if pendingLaunchRequest == nil {
      pendingLaunchRequest = store.pendingLaunchRequest()
    }
    if let pendingLaunchRequest {
      isKeyboardHandoffActive = true
      requiresManualKeyboardReturn = manualReturnRequired(
        for: pendingLaunchRequest
      )
    }

    if isRelayRunning {
      recoverIdleStateForPendingLaunchIfNeeded()
      preparePendingLaunchHandoffIfNeeded()
      scheduleIdleShutdownIfEligible()
    } else if pendingLaunchRequest != nil || configuration.autoStartRelayOnLaunch {
      await startRelay()
    }
  }

  func startRelay() async {
    guard !isRelayRunning, !isRelayStarting else { return }
    if UIApplication.shared.applicationState == .active,
      pendingLaunchRequest == nil
    {
      pendingLaunchRequest = store.pendingLaunchRequest()
    }
    relayStartupGeneration += 1
    let startupGeneration = relayStartupGeneration
    isRelayStarting = true
    defer { isRelayStarting = false }

    capture.recoveryHandler = { [weak self] result in
      Task { @MainActor [weak self] in
        guard let self,
          self.relayStartupGeneration == startupGeneration
        else {
          return
        }
        self.handleAudioRecovery(result)
      }
    }

    setLocalStatus(.offline, message: "Requesting microphone access…")
    let permissionGranted = await requestMicrophonePermission()
    guard startupGeneration == relayStartupGeneration else { return }
    guard permissionGranted else {
      discardPendingLaunchRequest()
      publishUnavailable(
        message: "Microphone access is off. Enable it in Settings, then try again."
      )
      return
    }

    guard configuration.hasUsableAPIKey else {
      discardPendingLaunchRequest()
      publishUnavailable(message: GeminiTranscriptionError.missingAPIKey.localizedDescription)
      return
    }

    do {
      try capture.start()
      isRelayRunning = true
      pendingAudioRecoveryError = nil
      relaySessionID = UUID().uuidString

      let snapshot = store.snapshot()
      lastHandledSequence = snapshot.handledCommandSequence
      beginPolling()
      if status == .offline {
        publish(.idle, message: "Ready — switch to the Gemini Voice keyboard")
      }
      preparePendingLaunchHandoffIfNeeded()
      pollRelayStore()
      markRelayActivityAndScheduleIdleShutdown()
    } catch {
      discardPendingLaunchRequest()
      publishUnavailable(message: error.localizedDescription)
    }
  }

  func stopRelay(
    message: String = "Relay stopped",
    offlineReason: RelayOfflineReason = .stopped
  ) {
    relayStartupGeneration += 1
    transcriptionGeneration += 1
    transcriptionTask?.cancel()
    transcriptionTask = nil
    processingRequestID = nil
    processingRecordingID = nil
    recoveryRetryTask?.cancel()
    recoveryRetryTask = nil
    maximumDurationWorkItem?.cancel()
    maximumDurationWorkItem = nil
    pendingFinishWorkItem?.cancel()
    pendingFinishWorkItem = nil
    idleShutdownWorkItem?.cancel()
    idleShutdownWorkItem = nil
    cancelAutomaticReturnToKeyboard()
    activeRequestID = nil
    activeDictationAction = nil
    activeStartedAt = nil
    pendingAudioRecoveryError = nil
    cancelLiveStream()
    discardPendingLaunchRequest()
    idleShutdownWorkItem?.cancel()
    idleShutdownWorkItem = nil

    capture.stop()
    pollTimer?.cancel()
    pollTimer = nil
    isRelayRunning = false
    relaySessionID = nil
    audioLevel = 0
    publish(.offline, message: message, offlineReason: offlineReason)
    liveActivity.end(message: message)
    isKeyboardHandoffActive = false
    endTranscriptionBackgroundTaskIfNeeded()
  }

  func applicationDidEnterBackground() {
    cancelAutomaticReturnToKeyboard()
    isKeyboardHandoffActive = false
    if configuration.autoStopRelayOnBackground, isRelayRunning {
      stopRelay(message: "Relay stopped (app in background)", offlineReason: .stopped)
    }
  }

  func cancelKeyboardHandoff() {
    if status == .recording, activeRequestID != nil {
      cancelDictation()
      return
    }
    discardPendingLaunchRequest()
    isKeyboardHandoffActive = false
  }

  func handleAudioRecovery(_ result: Result<String, Error>) {
    guard isRelayRunning else { return }

    // A delayed route-change result can arrive after capture has ended while
    // the complete request is finalizing. Preserve that result, then apply
    // any microphone failure after the transcript has been published.
    if status == .transcribing {
      switch result {
      case .success:
        pendingAudioRecoveryError = nil
      case .failure(let error):
        pendingAudioRecoveryError = error
      }
      return
    }

    maximumDurationWorkItem?.cancel()
    maximumDurationWorkItem = nil
    pendingFinishWorkItem?.cancel()
    pendingFinishWorkItem = nil
    activeRequestID = nil
    activeDictationAction = nil
    activeStartedAt = nil
    cancelLiveStream()
    audioLevel = 0
    isKeyboardHandoffActive = false

    switch result {
    case .success(let message):
      guard status != .transcribing else { return }
      publish(.idle, message: "\(message) — ready")
      markRelayActivityAndScheduleIdleShutdown()
    case .failure(let error):
      transcriptionGeneration += 1
      transcriptionTask?.cancel()
      transcriptionTask = nil
      pollTimer?.cancel()
      pollTimer = nil
      isRelayRunning = false
      publishUnavailable(message: error.localizedDescription)
      endTranscriptionBackgroundTaskIfNeeded()
    }
  }

  isolated deinit {
    transcriptionTask?.cancel()
    recoveryRetryTask?.cancel()
    idleShutdownWorkItem?.cancel()
    pollTimer?.cancel()
    capture.stop()
  }
}
