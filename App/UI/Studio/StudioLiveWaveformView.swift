import SwiftUI

struct StudioLiveWaveformView: View {
  var audioLevel: Double
  var isLive: Bool

  // FIX #5 (per Raj & Karen): Pre-computed static multipliers avoid 540 allocations/sec during audio streaming
  private static let barMultipliers: [CGFloat] = [0.38, 0.65, 0.92, 0.60, 1.0, 0.74, 0.88, 0.54, 0.35]

  var body: some View {
    HStack(alignment: .center, spacing: 6) {
      ForEach(0..<Self.barMultipliers.count, id: \.self) { index in
        let multiplier = Self.barMultipliers[index]
        let audio = CGFloat(audioLevel)
        let wave = sin(Double(index) * 0.85 + Double(audio) * .pi * 2.5) * 0.22
        let scale = max(0.08, audio * (multiplier + CGFloat(wave)))
        Capsule()
          .fill(
            isLive
              ? LinearGradient(
                  colors: [GeminiVoiceTheme.accentColor, Color(red: 119/255, green: 155/255, blue: 218/255)],
                  startPoint: .top,
                  endPoint: .bottom
                )
              : LinearGradient(
                  colors: [Color.secondary.opacity(0.3), Color.secondary.opacity(0.15)],
                  startPoint: .top,
                  endPoint: .bottom
                )
          )
          .frame(
            width: 7,
            height: isLive
              ? max(10, 10 + (64 * scale))
              : 8
          )
      }
    }
    .frame(height: 74)
    .animation(.spring(response: 0.12, dampingFraction: 0.52), value: audioLevel)
    .animation(.easeInOut(duration: 0.25), value: isLive)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isLive ? "Live microphone audio waveform visualizer" : "Microphone inactive")
  }
}
