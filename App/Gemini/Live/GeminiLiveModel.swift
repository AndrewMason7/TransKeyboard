import Foundation

public struct GeminiLiveModel: Identifiable, Hashable, Sendable {
  public let id: String
  public let displayName: String
  public let subtitle: String

  public init(id: String, displayName: String, subtitle: String) {
    self.id = id
    self.displayName = displayName
    self.subtitle = subtitle
  }

  public static let gemini35TranscribeLive = GeminiLiveModel(
    id: "gemini-3.5-transcribe-live",
    displayName: "gemini-3.5-transcribe-live",
    subtitle: "Real-time streaming speech recognition via Gemini Live"
  )

  public static let gemini35Transcribe = GeminiLiveModel(
    id: "gemini-3.5-transcribe",
    displayName: "gemini-3.5-transcribe",
    subtitle: "Cloud speech transcription via Gemini 3.5 Transcribe"
  )

  public static let localGemma = GeminiLiveModel(
    id: ModelDownloadManager.defaultModelFileName,
    displayName: ModelDownloadManager.defaultModelFileName,
    subtitle: "100% offline speech recognition with local Gemma processing"
  )

  public static let allAvailable: [GeminiLiveModel] = [
    .gemini35TranscribeLive,
    .gemini35Transcribe,
    .localGemma
  ]

  public static func displayName(for modelId: String) -> String {
    allAvailable.first(where: { $0.id == modelId })?.displayName ?? modelId
  }
}
