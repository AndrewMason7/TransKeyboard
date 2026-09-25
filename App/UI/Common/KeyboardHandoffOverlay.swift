import SwiftUI

struct KeyboardHandoffOverlay: View {
  @Bindable var relay: RelayController

  var body: some View {
    ZStack {
      // Blurred ambient backdrop
      Color.black.opacity(0.4)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        Spacer()

        VStack(spacing: 22) {
          // Brand gradient mark
          ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
              .fill(LinearGradient.geminiVoicePrimary)
              .frame(width: 84, height: 84)
              .shadow(color: GeminiVoiceTheme.accentColor.opacity(0.35), radius: 14, x: 0, y: 6)

            Image(systemName: "waveform.badge.mic")
              .font(.system(size: 38, weight: .semibold))
              .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.15))
              .symbolEffect(.variableColor.iterative, isActive: relay.status == .recording)
          }

          // Soundwaves visualizer
          soundwaveVisualizer

          // Title & Description
          VStack(spacing: 8) {
            Text(handoffTitle)
              .font(.title2.weight(.bold))
              .multilineTextAlignment(.center)
              .foregroundStyle(.primary)

            Text(handoffMessage)
              .font(.subheadline)
              .multilineTextAlignment(.center)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.horizontal, 16)

          if relay.status == .idle && !relay.requiresManualKeyboardReturn {
            Text("Recording begins automatically when the keyboard attaches.")
              .font(.caption)
              .multilineTextAlignment(.center)
              .foregroundStyle(GeminiVoiceTheme.accentColor)
              .padding(.horizontal, 20)
          }

          // Return to Host App Button (primary action when ready)
          if relay.status == .idle || relay.requiresManualKeyboardReturn {
            Button(action: relay.returnToHostApplication) {
              HStack(spacing: 8) {
                Image(systemName: "arrow.turn.up.left.circle.fill")
                  .font(.system(size: 17, weight: .semibold))
                Text("Return to \(relay.hostApplicationDisplayName)")
                  .font(.subheadline.weight(.bold))
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(LinearGradient.geminiVoicePrimary)
              .foregroundStyle(.white)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              .shadow(color: GeminiVoiceTheme.accentColor.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("relay-return-to-host-button")
            .accessibilityLabel("Return to \(relay.hostApplicationDisplayName)")
            .accessibilityHint("Switches back to \(relay.hostApplicationDisplayName) so you can continue dictating")
          }

          // Cancel action button
          Button(action: relay.cancelKeyboardHandoff) {
            Label(
              relay.status == .recording ? "Cancel recording" : "Cancel handoff",
              systemImage: "xmark.circle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.08))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
          .padding(.top, 4)
        }
        .padding(26)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 22)

        Spacer()
      }
    }
    .transition(.opacity.combined(with: .scale(scale: 0.96)))
    .accessibilityIdentifier("keyboard-handoff-overlay")
  }

  // FIX #5 (per Raj & Karen): Pre-computed static multipliers avoid frame allocations
  private static let barShapes: [CGFloat] = [0.42, 0.68, 0.9, 0.62, 1.0, 0.72, 0.86, 0.58, 0.38]

  private var soundwaveVisualizer: some View {
    HStack(alignment: .center, spacing: 6) {
      ForEach(0..<Self.barShapes.count, id: \.self) { index in
        let shape = Self.barShapes[index]
        Capsule()
          .fill(
            relay.status == .recording
              ? GeminiVoiceTheme.accentColor
              : Color.secondary.opacity(0.35)
          )
          .frame(
            width: 6,
            height: 12 + (54 * CGFloat(max(0.06, relay.audioLevel)) * shape)
          )
      }
    }
    .frame(height: 68)
    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: relay.audioLevel)
  }

  private var handoffTitle: String {
    switch relay.status {
    case .idle:
      #if GEMINI_PERSONAL_DEVICE
        return relay.requiresManualKeyboardReturn
          ? "Ready to Return"
          : "Returning to keyboard"
      #else
        return "Relay ready"
      #endif
    case .recording:
      return "Listening…"
    case .transcribing:
      return "Transcribing…"
    case .error:
      return "Check Setup"
    case .offline:
      return "Preparing microphone…"
    }
  }

  private var handoffMessage: String {
    switch relay.status {
    case .idle:
      #if GEMINI_PERSONAL_DEVICE
        if relay.requiresManualKeyboardReturn {
          return "Tap Return to \(relay.hostApplicationDisplayName) below or swipe back to begin dictating."
        }
        return "Gemini Voice is ready. Recording will start as soon as your keyboard is active."
      #else
        return "Gemini Voice is ready. Return to your text field to begin dictating."
      #endif
    case .recording:
      return "Gemini Voice is streaming audio while you dictate."
    case .transcribing, .error, .offline:
      return relay.statusMessage
    }
  }
}
