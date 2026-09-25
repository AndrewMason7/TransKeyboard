import SwiftUI
import UIKit

public enum GeminiVoiceTheme {
  /// The 5-color chromatic twilight gradient stops requested by the user:
  /// #FEFEFE, #E5A2A5, #D97F99, #C1B4CF, #779BDA
  public static let primaryGradientStops: [Color] = [
    Color(red: 254/255, green: 254/255, blue: 254/255), // #FEFEFE
    Color(red: 229/255, green: 162/255, blue: 165/255), // #E5A2A5
    Color(red: 217/255, green: 127/255, blue: 153/255), // #D97F99
    Color(red: 193/255, green: 180/255, blue: 207/255), // #C1B4CF
    Color(red: 119/255, green: 155/255, blue: 218/255)  // #779BDA
  ]

  public static let accentColor = Color(red: 217/255, green: 127/255, blue: 153/255) // #D97F99
  public static let accentUIColor = UIColor(red: 217/255, green: 127/255, blue: 153/255, alpha: 1.0)

  public static let translationAccent = Color(red: 135/255, green: 120/255, blue: 215/255)
  public static let translationUIAccent = UIColor(red: 135/255, green: 120/255, blue: 215/255, alpha: 1.0)

  static func statusTitle(for status: RelayStatus) -> String {
    switch status {
    case .offline: return "OFFLINE"
    case .idle: return "READY"
    case .recording: return "LISTENING"
    case .transcribing: return "TRANSCRIBING"
    case .error: return "CHECK SETUP"
    }
  }

  static func statusColor(for status: RelayStatus) -> Color {
    switch status {
    case .offline: return .gray
    case .idle: return .green
    case .recording: return .red
    case .transcribing: return .cyan
    case .error: return .orange
    }
  }
}

extension LinearGradient {
  public static var geminiVoicePrimary: LinearGradient {
    LinearGradient(
      colors: GeminiVoiceTheme.primaryGradientStops,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}
