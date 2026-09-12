import SwiftUI

struct KeyboardToolbarStatusPill: View {
  @ObservedObject var state: KeyboardToolbarState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if state.isProcessing {
        processingPill
      } else if state.isProcessingError, let message = state.processingMessage {
        errorPill(message: message)
      } else if state.mode == .recording {
        recordingPill
      } else if let status = state.brandStatusText {
        infoPill(text: status, color: state.brandStatusColor ?? .orange)
      } else {
        idlePill
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.mode)
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.isProcessing)
    .accessibilityIdentifier("keyboard-processing-status")
  }

  private var processingPill: some View {
    HStack(spacing: 6) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.cyan)
        .scaleEffect(0.75)
      Text(state.processingMessage ?? "Transcribing…")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.primary)
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(pillBackground)
  }

  private func errorPill(message: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.orange)
      Text(message)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.orange)
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(pillBackground)
  }

  private var recordingPill: some View {
    RecordingPillView(
      timerText: state.timerText,
      audioVisualizer: state.audioVisualizer
    )
  }

  private func infoPill(text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(color)
      .lineLimit(1)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(pillBackground)
  }

  private var idlePill: some View {
    HStack(spacing: 5) {
      Image(systemName: "waveform")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(state.targetLanguage.code.uppercased())
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
    )
  }

  private var pillBackground: some View {
    Capsule()
      .fill(.ultraThinMaterial)
      .overlay {
        Capsule()
          .strokeBorder(
            Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35),
            lineWidth: 0.5
          )
      }
      .shadow(
        color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08),
        radius: 2,
        x: 0,
        y: 1
      )
  }
}

private struct RecordingPillView: View {
  let timerText: String?
  @ObservedObject var audioVisualizer: KeyboardAudioVisualizerState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(.red)
        .frame(width: 7, height: 7)

      if let timerText {
        Text(timerText)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundStyle(.red)
      }

      MiniWaveformIndicator(level: audioVisualizer.audioLevel)
        .frame(width: 24, height: 12)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(
      Capsule()
        .fill(.ultraThinMaterial)
        .overlay {
          Capsule()
            .strokeBorder(
              Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35),
              lineWidth: 0.5
            )
        }
        .shadow(
          color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08),
          radius: 2,
          x: 0,
          y: 1
        )
    )
  }
}
