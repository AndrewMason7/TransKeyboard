import Foundation

public enum FeatureFlagCategory: String, CaseIterable, Identifiable, Sendable {
  case speechAndAI = "Speech & AI"
  case extensions = "App Extensions"
  case studio = "Studio Tools"
  case diagnostics = "Developer & Diagnostics"

  public var id: String { rawValue }
  public var systemImage: String {
    switch self {
    case .speechAndAI: return "waveform.badge.mic"
    case .extensions: return "square.stack.3d.up.fill"
    case .studio: return "wand.and.stars"
    case .diagnostics: return "ant.fill"
    }
  }
}

public enum FeatureFlag: String, CaseIterable, Identifiable, Sendable {
  // Speech & AI
  case geminiLiveStreaming = "gemini_live_streaming"
  case geminiBatchFallback = "gemini_batch_fallback"
  case onDeviceGemma = "on_device_gemma"

  // App Extensions
  case liveActivity = "live_activity"
  case keyboardHandoff = "keyboard_handoff"

  // Studio Tools
  case visualOCR = "visual_ocr"
  case waveformVisualizer = "waveform_visualizer"

  // Developer & Diagnostics
  case verboseDiagnostics = "verbose_diagnostics"
  case simulatedFailures = "simulated_failures"

  public var id: String { rawValue }

  public var category: FeatureFlagCategory {
    switch self {
    case .geminiLiveStreaming, .geminiBatchFallback, .onDeviceGemma:
      return .speechAndAI
    case .liveActivity, .keyboardHandoff:
      return .extensions
    case .visualOCR, .waveformVisualizer:
      return .studio
    case .verboseDiagnostics, .simulatedFailures:
      return .diagnostics
    }
  }

  public var title: String {
    switch self {
    case .geminiLiveStreaming: return "Gemini Live Streaming"
    case .geminiBatchFallback: return "Gemini Batch Fallback"
    case .onDeviceGemma: return "On-Device Gemma Model"
    case .liveActivity: return "Dynamic Island / Live Activity"
    case .keyboardHandoff: return "Keyboard Handoff Overlay"
    case .visualOCR: return "Visual OCR Scanner"
    case .waveformVisualizer: return "Real-time Waveform Visualizer"
    case .verboseDiagnostics: return "Verbose Launch Diagnostics"
    case .simulatedFailures: return "Simulate Service Failures"
    }
  }

  public var subtitle: String {
    switch self {
    case .geminiLiveStreaming:
      return "Enables real-time bidirectional WebSocket dictation and translation."
    case .geminiBatchFallback:
      return "Allows fallback to REST audio transcription when offline or interrupted."
    case .onDeviceGemma:
      return "Enables on-device speech transcription and local rewriting."
    case .liveActivity:
      return "Shows live dictation waveform and status in the Dynamic Island and Lock Screen."
    case .keyboardHandoff:
      return "Displays the floating prompt card when launching the app from the keyboard."
    case .visualOCR:
      return "Enables image-based text recognition in the Studio playground."
    case .waveformVisualizer:
      return "Renders interactive audio waveform bars during relay recording."
    case .verboseDiagnostics:
      return "Outputs detailed relay and socket diagnostic logs to the system console."
    case .simulatedFailures:
      return "Simulates intermittent network or recognition timeouts for testing."
    }
  }

  public var defaultValue: Bool {
    switch self {
    case .geminiLiveStreaming, .geminiBatchFallback, .onDeviceGemma,
      .liveActivity, .keyboardHandoff, .visualOCR, .waveformVisualizer:
      return true
    case .verboseDiagnostics, .simulatedFailures:
      return false
    }
  }
}
