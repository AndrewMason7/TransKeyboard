import Observation
import SwiftUI

@Observable
@MainActor
final class KeyboardRecordingCardState {
  var modeName: String
  var modeIcon: String
  var title: String
  let audioVisualizer: KeyboardAudioVisualizerState

  init(
    modeName: String = SpeechEngineMode.defaultMode.displayName,
    modeIcon: String = SpeechEngineMode.defaultMode.iconName,
    title: String = "Listening",
    audioVisualizer: KeyboardAudioVisualizerState = KeyboardAudioVisualizerState()
  ) {
    self.modeName = modeName
    self.modeIcon = modeIcon
    self.title = title
    self.audioVisualizer = audioVisualizer
  }
}

struct KeyboardRecordingCardView: View {
  var state: KeyboardRecordingCardState

  @Environment(\.colorScheme) private var colorScheme

  private static let barMultipliers: [CGFloat] = [0.38, 0.65, 0.92, 0.60, 1.0, 0.74, 0.88, 0.54, 0.35]

  init(state: KeyboardRecordingCardState) {
    self.state = state
  }

  init(modeName: String, modeIcon: String, title: String, visualizer: KeyboardAudioVisualizerState) {
    self.state = KeyboardRecordingCardState(
      modeName: modeName,
      modeIcon: modeIcon,
      title: title,
      audioVisualizer: visualizer
    )
  }

  var body: some View {
    VStack(spacing: 14) {
      // Top: Active Model Badge Pill
      HStack(spacing: 5) {
        Image(systemName: state.modeIcon)
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GeminiVoiceTheme.accentColor)

        Text(state.modeName)
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .foregroundStyle(GeminiVoiceTheme.accentColor)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4.5)
      .background(
        Capsule()
          .fill(GeminiVoiceTheme.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08))
      )
      .overlay {
        Capsule()
          .stroke(
            GeminiVoiceTheme.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.20),
            lineWidth: 0.5
          )
      }

      // Middle: Chromatic Twilight Dancing Waveform Visualizer
      HStack(alignment: .center, spacing: 6) {
        ForEach(0..<Self.barMultipliers.count, id: \.self) { index in
          let multiplier = Self.barMultipliers[index]
          let audio = CGFloat(state.audioVisualizer.audioLevel)
          let wave = sin(Double(index) * 0.85 + Double(audio) * .pi * 2.5) * 0.22
          let scale = max(0.08, audio * (multiplier + CGFloat(wave)))
          let height = max(10, 10 + (64 * scale))
          Capsule()
            .fill(
              LinearGradient(
                colors: [
                  GeminiVoiceTheme.accentColor,
                  Color(red: 119/255, green: 155/255, blue: 218/255)
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(width: 7, height: height)
        }
      }
      .frame(height: 74)
      .animation(.spring(response: 0.12, dampingFraction: 0.52), value: state.audioVisualizer.audioLevel)

      // Bottom: Dynamic Status Title
      Text(state.title)
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(Color.primary)
        .lineLimit(1)
        .contentTransition(.opacity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.vertical, 16)
    .padding(.horizontal, 20)
    .background {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(
              Color.white.opacity(colorScheme == .dark ? 0.14 : 0.28),
              lineWidth: 0.5
            )
        }
        .shadow(
          color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08),
          radius: 8,
          x: 0,
          y: 3
        )
    }
    .padding(.horizontal, 4)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("keyboard-recording-panel")
    .accessibilityLabel("\(state.title), using \(state.modeName)")
  }
}
