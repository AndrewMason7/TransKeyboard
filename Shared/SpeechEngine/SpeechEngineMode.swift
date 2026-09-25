import Foundation

public enum SpeechEngineMode: String, CaseIterable, Identifiable, Codable, Sendable {
  case geminiLive = "geminiLive"
  case geminiBatch = "geminiBatch"
  case localOnDevice = "localOnDevice"
  case autoFallback = "autoFallback"

  public static let defaultMode: SpeechEngineMode = .geminiLive
  public static let sharedDefaultsKey = "configuration.speech-engine-mode"
  public static let activeModelIdentifierKey = "configuration.active-model-identifier"
  public static let defaultModelIdentifier = "gemini-3.5-transcribe-live"

  public static func mode(for modelIdentifier: String) -> SpeechEngineMode {
    switch modelIdentifier {
    case "gemini-3.5-transcribe":
      return .geminiBatch
    case "gemma-4-E2B-it.litert-lm", "gemma", "gemma-2b-it-q4.bin", "gemma-4-E2B-it-litert-lm":
      return .localOnDevice
    default:
      return .geminiLive
    }
  }

  public static func iconName(for modelIdentifier: String) -> String {
    mode(for: modelIdentifier).iconName
  }

  public var id: String { rawValue }

  public var shortName: String {
    switch self {
    case .geminiLive:
      return "Gemini 3.5 Live"
    case .geminiBatch:
      return "Gemini Transcribe"
    case .localOnDevice:
      return "Local On-Device"
    case .autoFallback:
      return "Auto-Fallback"
    }
  }

  public var displayName: String {
    switch self {
    case .geminiLive:
      return "Gemini Live (Cloud)"
    case .geminiBatch:
      return "Gemini 3.5 Transcribe (Cloud)"
    case .localOnDevice:
      return "Local On-Device"
    case .autoFallback:
      return "Gemini Live with Fallback"
    }
  }

  public var subtitle: String {
    switch self {
    case .geminiLive:
      return "Ultra-low latency streaming using Google Gemini 3.5 Live."
    case .geminiBatch:
      return "Cloud speech transcription using Google Gemini 3.5 Transcribe."
    case .localOnDevice:
      return "100% offline speech recognition with optional local Gemma processing."
    case .autoFallback:
      return "Uses Gemini Cloud by default, and automatically falls back to offline if you lose cell signal."
    }
  }

  public var iconName: String {
    switch self {
    case .geminiLive:
      return "bolt.badge.automatic.fill"
    case .geminiBatch:
      return "cloud.fill"
    case .localOnDevice:
      return "lock.shield.fill"
    case .autoFallback:
      return "arrow.triangle.swap"
    }
  }

  public var badgeText: String {
    switch self {
    case .geminiLive:
      return "RECOMMENDED"
    case .geminiBatch:
      return "BATCH"
    case .localOnDevice:
      return "100% PRIVATE"
    case .autoFallback:
      return "SMART HYBRID"
    }
  }

  public var latencyEstimate: String {
    switch self {
    case .geminiLive:
      return "< 300ms"
    case .geminiBatch:
      return "~1-2s"
    case .localOnDevice:
      return "Real-time"
    case .autoFallback:
      return "Adaptive"
    }
  }

  public var featureHighlights: [String] {
    switch self {
    case .geminiLive:
      return [
        "Bidirectional WebSocket streaming",
        "Continuous real-time transcription",
        "Lowest end-to-end latency"
      ]
    case .geminiBatch:
      return [
        "Full audio uploaded upon finishing",
        "Google Gemini 3.5 Flash backend",
        "High precision transcription"
      ]
    case .localOnDevice:
      return [
        "Zero network data sent off device",
        "Runs on Apple Speech framework",
        "Optional Gemma AI post-processing"
      ]
    case .autoFallback:
      return [
        "Primary Gemini Live cloud streaming",
        "Automatic failover to offline on-device speech",
        "Never drops dictation when losing cell service"
      ]
    }
  }
}
