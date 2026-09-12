import AVFoundation
import Foundation

extension AudioCaptureEngine {
  var sessionConfigurations: [SessionConfiguration] {
    var configurations: [SessionConfiguration] = []
    if #available(iOS 26.0, *) {
      configurations.append(
        SessionConfiguration(
          name: "AirPods high-quality",
          mode: .default,
          options: [.mixWithOthers, .allowBluetoothHFP, .bluetoothHighQualityRecording]
        )
      )
    }
    configurations.append(contentsOf: [
      SessionConfiguration(
        name: "Bluetooth mixed",
        mode: .default,
        options: [.mixWithOthers, .allowBluetoothHFP, .allowBluetoothA2DP]
      ),
      SessionConfiguration(
        name: "Bluetooth hands-free",
        mode: .default,
        options: [.mixWithOthers, .allowBluetoothHFP]
      ),
      SessionConfiguration(
        name: "Built-in mixed",
        mode: .default,
        options: [.mixWithOthers]
      ),
    ])
    return configurations
  }

  func reportRecoverableRecordings() {
    guard let container = VoiceAppGroup.containerURL else { return }
    let directory = container.appendingPathComponent("Recordings", isDirectory: true)
    guard
      let urls = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else { return }

    let recoverableCount = urls.filter {
      $0.lastPathComponent.hasPrefix("completed-")
        && $0.pathExtension.lowercased() == "wav"
    }.count
    if recoverableCount > 0 {
      NSLog("AUDIO_RECOVERABLE_RECORDINGS_PRESERVED count=%d", recoverableCount)
    }
  }

  func startEngine(using configuration: SessionConfiguration) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: configuration.mode,
      options: configuration.options
    )
    try? session.setPreferredSampleRate(16_000)
    try? session.setPreferredInputNumberOfChannels(1)
    try? session.setPreferredIOBufferDuration(0.02)
    try session.setActive(true, options: [])

    // An engine retained across a route change can expose the old output
    // format even after session activation. Never reinstall a tap on that graph.
    replaceStoppedEngine()
    let input = engine.inputNode
    let hardwareFormat = input.inputFormat(forBus: 0)
    let format = input.outputFormat(forBus: 0)
    guard Self.isUsableInputFormat(format, hardwareFormat: hardwareFormat) else {
      NSLog("IOS_VALIDATION_FAILURE microphone route format unavailable or changing")
      throw AudioCaptureError.invalidInputFormat
    }

    input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
      self?.write(buffer)
    }
    tapInstalled = true
    inputFormat = format
    configureStreamingConverter(from: format)

    engine.prepare()
    try engine.start()
    isRunning = true
  }

  func tearDownEngine() {
    // Stop delivery before removing the tap and releasing converter state.
    engine.stop()
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: [.notifyOthersOnDeactivation]
    )
    fileLock.lock()
    inputFormat = nil
    streamingConverter = nil
    streamingOutputFormat = nil
    streamingChunker.reset()
    audioChunkHandler = nil
    audioStreamingFailureHandler = nil
    didReportStreamingFailure = false
    fileLock.unlock()
    isRunning = false
    activeConfigurationName = ""
  }

  func handleInterruption(_ notification: Notification) {
    guard shouldBeRunning,
      let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else { return }

    switch type {
    case .began:
      NSLog("AUDIO_RELAY_INTERRUPTED route=%@", routeDescription)
      isRunning = false
    case .ended:
      scheduleRecovery(reason: "audio interruption ended")
    @unknown default:
      break
    }
  }

  func scheduleRecovery(reason: String) {
    guard shouldBeRunning, !isConfiguring else { return }
    recoveryWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.shouldBeRunning, !self.isConfiguring else { return }
      self.recover(reason: reason)
    }
    recoveryWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
  }

  func replaceEngineAndRecover() {
    guard shouldBeRunning else { return }
    recoveryWorkItem?.cancel()
    cancelSegment()
    tearDownEngine()
    replaceStoppedEngine()
    scheduleRecovery(reason: "media services reset")
  }

  static func isUsableInputFormat(
    _ format: AVAudioFormat,
    hardwareFormat: AVAudioFormat
  ) -> Bool {
    hardwareFormat.sampleRate.isFinite && hardwareFormat.sampleRate > 0
      && hardwareFormat.channelCount > 0
      && format.sampleRate == hardwareFormat.sampleRate
      && format.channelCount == hardwareFormat.channelCount
  }

  /// Call only after teardown or before a fresh session's first tap.
  func replaceStoppedEngine() {
    if let engineConfigurationObserver {
      NotificationCenter.default.removeObserver(engineConfigurationObserver)
    }
    engine = AVAudioEngine()
    observeEngineConfiguration()
  }

  func observeEngineConfiguration() {
    engineConfigurationObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: engine,
      queue: .main
    ) { [weak self, weak observedEngine = engine] _ in
      guard let self, let observedEngine, self.engine === observedEngine else { return }
      self.scheduleRecovery(reason: "audio route changed")
    }
  }

  func recover(reason: String) {
    let interruptedActiveSegment = hasActiveSegment
    if interruptedActiveSegment {
      cancelSegment()
    }
    tearDownEngine()

    do {
      try start()
      let message =
        interruptedActiveSegment
        ? "Audio recovered after \(reason); the interrupted dictation was cancelled"
        : "Audio recovered after \(reason)"
      NSLog("AUDIO_RELAY_RECOVERED reason=%@ route=%@", reason, routeDescription)
      recoveryHandler?(.success(message))
    } catch {
      NSLog("AUDIO_RELAY_RECOVERY_FAILED reason=%@ error=%@", reason, errorSummary(error))
      recoveryHandler?(.failure(error))
    }
  }

  var hasActiveSegment: Bool {
    fileLock.lock()
    defer { fileLock.unlock() }
    return activeFile != nil
  }

  var routeDescription: String {
    let route = AVAudioSession.sharedInstance().currentRoute
    let inputs = route.inputs.map { "\($0.portType.rawValue):\($0.portName)" }
    let outputs = route.outputs.map { "\($0.portType.rawValue):\($0.portName)" }
    return "input=[\(inputs.joined(separator: ","))] output=[\(outputs.joined(separator: ","))]"
  }

  func errorSummary(_ error: Error) -> String {
    let nsError = error as NSError
    return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
  }
}
