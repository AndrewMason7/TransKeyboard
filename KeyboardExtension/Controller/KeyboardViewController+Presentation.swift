import SwiftUI
import UIKit

extension KeyboardViewController {
  func configureMicrophone(title: String, image: String, color: UIColor) {
    let accessibilityLabel: String
    let accessibilityHint: String?
    switch title {
    case "Finish":
      accessibilityLabel = "Finish dictation and insert text"
      accessibilityHint = "Ends this recording and sends it for transcription"
    case "Transcribing":
      accessibilityLabel = "Transcribing with Gemini"
      accessibilityHint = nil
    case "Try again":
      accessibilityLabel = "Start Gemini dictation again"
      accessibilityHint = nil
    case "Open & dictate":
      accessibilityLabel = "Open Gemini Voice and start dictation"
      accessibilityHint = nil
    case "Opening…":
      accessibilityLabel = "Opening Gemini Voice"
      accessibilityHint = nil
    case "Starting…":
      accessibilityLabel = "Starting Gemini dictation"
      accessibilityHint = nil
    default:
      accessibilityLabel = "Start Gemini dictation"
      accessibilityHint = nil
    }
    toolbarState.configureMicrophone(
      image: image,
      color: Color(uiColor: color),
      accessibilityLabel: accessibilityLabel,
      accessibilityHint: accessibilityHint
    )
  }

  var keyboardTranslationEnabled: Bool {
    true
  }

  var keyboardTranslationTarget: TranslationLanguage {
    let code =
      sharedPreferences.string(forKey: TranslationPreferenceKey.targetCode)
      ?? TranslationLanguage.defaultLanguage.code
    return TranslationLanguage.language(for: code)
  }

  func configureTranslationButton(
    title: String? = nil,
    image: String = "character.bubble.fill",
    color: UIColor = GeminiVoiceTheme.translationUIAccent
  ) {
    let target = keyboardTranslationTarget
    let accessibilityLabel: String
    let accessibilityHint: String?
    switch title {
    case "Finish":
      accessibilityLabel = "Finish translation and insert text"
      accessibilityHint =
        "Ends this recording and sends it for translation to \(target.name)"
    case "…":
      accessibilityLabel = "Translating with Gemini"
      accessibilityHint = nil
    default:
      accessibilityLabel = "Start dictation and translate to \(target.name)"
      accessibilityHint = nil
    }
    toolbarState.configureTranslation(
      image: image,
      color: Color(uiColor: color),
      targetLanguage: target,
      accessibilityLabel: accessibilityLabel,
      accessibilityHint: accessibilityHint
    )
  }

  func updateActionVisibility() {
    toolbarState.isCancelHidden = (mode == .idle)
    toolbarState.isTranslateHidden = false
  }

  func updateCancelAccessibility() {
    let label: String
    let hint: String?
    switch mode {
    case .openingHost:
      label = "Cancel opening Gemini Voice"
      hint = "Cancels this dictation request before recording starts"
    case .recording:
      if activeDictationAction == .translate {
        label = "Cancel translation"
      } else {
        label = "Cancel dictation"
      }
      hint = "Stops and discards this recording without inserting text"
      case .transcribing:
        label =
          activeDictationAction == .translate
          ? "Cancel translation"
          : "Cancel transcription"
        hint = "Stops processing and discards the result without inserting text"
      case .cancelling:
        label = "Cancelling"
        hint = nil
      case .idle, .resultWaiting:
        label = "Cancel"
        hint = nil
      }
    toolbarState.cancelAccessibilityLabel = label
    toolbarState.cancelAccessibilityHint = hint
  }

  var activeSpeechEngineMode: SpeechEngineMode {
    let raw = sharedPreferences.string(forKey: SpeechEngineMode.sharedDefaultsKey)
    return raw.flatMap(SpeechEngineMode.init(rawValue:)) ?? .defaultMode
  }

  var activeRawModelIdentifier: String {
    let raw = sharedPreferences.string(forKey: SpeechEngineMode.activeModelIdentifierKey)
    if let raw, !raw.isEmpty {
      return raw
    }
    return activeSpeechEngineMode == .localOnDevice ? "gemma-4-E2B-it.litert-lm" : SpeechEngineMode.defaultModelIdentifier
  }

  func updateRecordingPresentation(with snapshot: RelaySnapshot) {
    let isRecording = mode == .recording
    recordingPanel.isHidden = !isRecording
    typingStack.isHidden = isRecording

    guard isRecording else {
      recordingCardState.audioVisualizer.updateAudioLevel(0)
      toolbarState.updateAudioLevel(0)
      return
    }

    let levelIsFresh =
      snapshot.audioLevelUpdatedAt.map {
        Date().timeIntervalSince($0) >= 0 && Date().timeIntervalSince($0) < 0.8
      } ?? false
    let currentLevel = levelIsFresh ? CGFloat(snapshot.audioLevel) : 0
    toolbarState.updateAudioLevel(currentLevel)

    let rawModel = activeRawModelIdentifier
    recordingCardState.modeName = rawModel
    recordingCardState.modeIcon = SpeechEngineMode.iconName(for: rawModel)
    recordingCardState.title =
      activeDictationAction == .translate
      ? "Listening to translate"
      : "Listening"
    recordingCardState.audioVisualizer.updateAudioLevel(currentLevel)
  }

  func updateProcessingPresentation(with snapshot: RelaySnapshot) {
    if mode == .transcribing {
      let label =
        activeDictationAction == .translate
        ? "Translating…"
        : "Transcribing…"
      toolbarState.updateProcessing(isProcessing: true, isError: false, message: label)
      return
    }

    if snapshot.status == .error {
      toolbarState.updateProcessing(isProcessing: false, isError: true, message: snapshot.message)
      return
    }

    toolbarState.updateProcessing(isProcessing: false, isError: false, message: nil)
  }

  func setStatus(_ text: String, color: UIColor) {
    toolbarState.setBrandStatus(text: text, color: Color(uiColor: color))
  }
}
