import SwiftUI

struct KeyboardToolbarStatusPill: View {
  var state: KeyboardToolbarState
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
        .scaleEffect(0.65)
      Text(state.processingMessage ?? "Transcribing…")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(Color.cyan)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(Color.cyan.opacity(colorScheme == .dark ? 0.14 : 0.08))
    )
    .overlay(
      Capsule()
        .stroke(Color.cyan.opacity(colorScheme == .dark ? 0.28 : 0.20), lineWidth: 0.5)
    )
  }

  private func errorPill(message: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Color.orange)
      Text(message)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(Color.orange)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(Color.orange.opacity(colorScheme == .dark ? 0.14 : 0.08))
    )
    .overlay(
      Capsule()
        .stroke(Color.orange.opacity(colorScheme == .dark ? 0.28 : 0.20), lineWidth: 0.5)
    )
  }

  private var recordingPill: some View {
    RecordingPillView(
      timerText: state.timerText,
      audioVisualizer: state.audioVisualizer
    )
  }

  private func infoPill(text: String, color: Color) -> some View {
    HStack(spacing: 5) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text(text)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(color)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(color.opacity(colorScheme == .dark ? 0.14 : 0.08))
    )
    .overlay(
      Capsule()
        .stroke(color.opacity(colorScheme == .dark ? 0.28 : 0.20), lineWidth: 0.5)
    )
  }

  private var idlePill: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(Color.green)
        .frame(width: 6, height: 6)
      Text("READY")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(Color.green)
      Text("•")
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(Color.secondary.opacity(0.5))
      Text(state.targetLanguage.code.uppercased())
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(Color.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(Color.green.opacity(colorScheme == .dark ? 0.12 : 0.08))
    )
    .overlay(
      Capsule()
        .stroke(Color.green.opacity(colorScheme == .dark ? 0.25 : 0.20), lineWidth: 0.5)
    )
  }
}

private struct RecordingPillView: View {
  let timerText: String?
  var audioVisualizer: KeyboardAudioVisualizerState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(Color.red)
        .frame(width: 6, height: 6)
        .symbolEffect(.pulse)

      if let timerText {
        Text(timerText)
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(Color.red)
      }

      MiniWaveformIndicator(level: audioVisualizer.audioLevel)
        .frame(width: 22, height: 12)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(Color.red.opacity(colorScheme == .dark ? 0.15 : 0.10))
    )
    .overlay(
      Capsule()
        .stroke(Color.red.opacity(colorScheme == .dark ? 0.32 : 0.24), lineWidth: 0.5)
    )
  }
}
