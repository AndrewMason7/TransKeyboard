import Foundation

public protocol LocalTextProcessing: Sendable {
  func formatTranscript(_ rawText: String) async -> String
  func translateText(_ rawText: String, targetLanguageCode: String) async -> String
}

public actor LocalTextProcessor: LocalTextProcessing {
  private let modelDownloadManager: ModelDownloadManager?

  public init(modelDownloadManager: ModelDownloadManager? = nil) {
    self.modelDownloadManager = modelDownloadManager
  }

  public func formatTranscript(_ rawText: String) async -> String {
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    if let manager = modelDownloadManager, await manager.isModelReady {
      return await formatWithGemma(trimmed)
    }

    return heuristicPunctuation(trimmed)
  }

  public func translateText(_ rawText: String, targetLanguageCode: String) async -> String {
    let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    if let manager = modelDownloadManager, await manager.isModelReady {
      return await translateWithGemma(trimmed, targetLanguageCode: targetLanguageCode)
    }

    return trimmed
  }

  private func heuristicPunctuation(_ text: String) -> String {
    var result = text
    if let first = result.first, first.isLowercase {
      result = first.uppercased() + result.dropFirst()
    }
    if let last = result.last, !".?!,".contains(last) {
      result.append(".")
    }
    return result
  }

  private func formatWithGemma(_ text: String) async -> String {
    // Scaffold ready for LiteRT-LM runtime invocation
    return heuristicPunctuation(text)
  }

  private func translateWithGemma(_ text: String, targetLanguageCode: String) async -> String {
    // Scaffold ready for LiteRT-LM runtime invocation
    return text
  }
}
