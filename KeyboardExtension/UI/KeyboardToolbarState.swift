import Observation
import SwiftUI

@Observable
@MainActor
final class KeyboardAudioVisualizerState {
  var audioLevel: CGFloat = 0.0

  func updateAudioLevel(_ level: CGFloat) {
    let safeLevel: CGFloat = (level.isFinite && !level.isNaN) ? max(0.0, min(1.0, level)) : 0.0
    if abs(self.audioLevel - safeLevel) > 0.02 || (safeLevel == 0 && self.audioLevel != 0) {
      self.audioLevel = safeLevel
    }
  }
}

enum KeyboardDictationMode: Sendable {
  case idle
  case openingHost
  case recording
  case cancelling
  case transcribing
  case resultWaiting
}

@Observable
@MainActor
final class KeyboardToolbarState {
  var mode: KeyboardDictationMode = .idle
  var activeAction: RelayDictationAction?

  // Microphone
  var isMicrophoneEnabled = true
  var microphoneImage = "mic.fill"
  var microphoneColor: Color = GeminiVoiceTheme.accentColor
  var microphoneAccessibilityLabel = "Start Gemini dictation"
  var microphoneAccessibilityHint: String?

  // Translation
  var isTranslateEnabled = true
  var isTranslateHidden = false
  var translateImage = "character.bubble.fill"
  var translateColor: Color = GeminiVoiceTheme.translationAccent
  var targetLanguage: TranslationLanguage = .defaultLanguage
  var translateAccessibilityLabel = "Start dictation and translate"
  var translateAccessibilityHint: String?

  // Cancel
  var isCancelEnabled = false
  var isCancelHidden = true
  var cancelAccessibilityLabel = "Cancel"
  var cancelAccessibilityHint: String?

  // Processing & Status
  var isProcessing = false
  var processingMessage: String?
  var isProcessingError = false
  var brandStatusText: String?
  var brandStatusColor: Color?

  // Live Timer
  var timerText: String?

  // Dedicated Audio Visualizer State (Isolated to prevent root toolbar re-renders)
  let audioVisualizer = KeyboardAudioVisualizerState()
  var audioLevel: CGFloat { audioVisualizer.audioLevel }

  // Action callbacks
  @ObservationIgnored var onBrandTap: (() -> Void)?
  @ObservationIgnored var onMicrophoneTap: (() -> Void)?
  @ObservationIgnored var onTranslateTap: (() -> Void)?
  @ObservationIgnored var onCancelTap: (() -> Void)?

  // MARK: - Atomic Mutators (Diff-Gated to Eliminate Redundant Publisher Emissions)

  func applySync(
    mode: KeyboardDictationMode,
    activeAction: RelayDictationAction?,
    isMicrophoneEnabled: Bool? = nil,
    isTranslateEnabled: Bool? = nil,
    isCancelEnabled: Bool? = nil,
    timerText: String? = nil
  ) {
    let cancelHidden = (mode == .idle)
    if self.mode != mode { self.mode = mode }
    if self.activeAction != activeAction { self.activeAction = activeAction }
    if let isMicrophoneEnabled, self.isMicrophoneEnabled != isMicrophoneEnabled {
      self.isMicrophoneEnabled = isMicrophoneEnabled
    }
    if let isTranslateEnabled, self.isTranslateEnabled != isTranslateEnabled {
      self.isTranslateEnabled = isTranslateEnabled
    }
    if let isCancelEnabled, self.isCancelEnabled != isCancelEnabled {
      self.isCancelEnabled = isCancelEnabled
    }
    if self.isCancelHidden != cancelHidden { self.isCancelHidden = cancelHidden }
    if self.timerText != timerText { self.timerText = timerText }
  }

  func configureMicrophone(
    image: String,
    color: Color,
    accessibilityLabel: String,
    accessibilityHint: String?
  ) {
    if self.microphoneImage != image { self.microphoneImage = image }
    if self.microphoneColor != color { self.microphoneColor = color }
    if self.microphoneAccessibilityLabel != accessibilityLabel { self.microphoneAccessibilityLabel = accessibilityLabel }
    if self.microphoneAccessibilityHint != accessibilityHint { self.microphoneAccessibilityHint = accessibilityHint }
  }

  func configureTranslation(
    image: String,
    color: Color,
    targetLanguage: TranslationLanguage,
    accessibilityLabel: String,
    accessibilityHint: String?
  ) {
    if self.translateImage != image { self.translateImage = image }
    if self.translateColor != color { self.translateColor = color }
    if self.targetLanguage != targetLanguage { self.targetLanguage = targetLanguage }
    if self.translateAccessibilityLabel != accessibilityLabel { self.translateAccessibilityLabel = accessibilityLabel }
    if self.translateAccessibilityHint != accessibilityHint { self.translateAccessibilityHint = accessibilityHint }
  }

  func updateProcessing(
    isProcessing: Bool,
    isError: Bool,
    message: String?
  ) {
    if self.isProcessing != isProcessing { self.isProcessing = isProcessing }
    if self.isProcessingError != isError { self.isProcessingError = isError }
    if self.processingMessage != message { self.processingMessage = message }
  }

  func updateAudioLevel(_ level: CGFloat) {
    audioVisualizer.updateAudioLevel(level)
  }

  func setBrandStatus(text: String, color: Color) {
    if self.brandStatusText != text { self.brandStatusText = text }
    if self.brandStatusColor != color { self.brandStatusColor = color }
  }
}
