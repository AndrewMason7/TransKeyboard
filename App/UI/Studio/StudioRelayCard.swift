import SwiftUI

struct StudioRelayCard: View {
  @Bindable var configuration: AppConfiguration
  @Bindable var relay: RelayController

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      // Top status row
      HStack {
        StatusPillView(status: relay.status, isRelayRunning: relay.isRelayRunning)
        Spacer()
        Text(configuration.activeTranscriptionModelDisplay)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      // Title & status message
      VStack(alignment: .leading, spacing: 6) {
        Text(relayHeading)
          .font(.title3.weight(.bold))
          .foregroundStyle(.primary)

        Text(relay.statusMessage)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if relay.isRelayRunning {
          Text(
            "Microphone session is armed. When dictating from your keyboard, audio streams live. Turns off automatically after 10 minutes without dictation."
          )
          .font(.caption)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 2)
        }

        if !configuration.hasUsableAPIKey && configuration.speechEngineMode != .appleSpeech && configuration.speechEngineMode != .localOnDevice {
          Button {
            configuration.selectedModelId = AppConfiguration.appleSpeechModelIdentifier
            Task { await relay.startRelay() }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "apple.logo")
              Text("Switch to Apple Speech (Offline • No Key Needed)")
                .font(.caption.weight(.semibold))
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(GeminiVoiceTheme.accentColor.opacity(0.12))
            .foregroundStyle(GeminiVoiceTheme.accentColor)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .padding(.top, 4)
        }
      }

      // Live waveform visualizer right inside the relay card
      if FeatureFlagStore.shared[.waveformVisualizer] {
        StudioLiveWaveformView(
          audioLevel: relay.audioLevel,
          isLive: relay.status == .recording || relay.isRelayRunning
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
      }

      // Primary tactile relay button
      Button(action: toggleRelayState) {
        HStack(spacing: 10) {
          Image(systemName: relay.isRelayRunning ? "stop.fill" : "mic.fill")
            .contentTransition(.symbolEffect(.replace))
          Text(
            relay.isRelayRunning
              ? "Stop Until Next Open"
              : relay.isRelayStarting
                ? "Starting Relay…"
                : "Start Relay Now"
          )
          .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
          relay.isRelayRunning
            ? Color.primary.opacity(0.12)
            : GeminiVoiceTheme.accentColor
        )
        .foregroundStyle(relay.isRelayRunning ? Color.primary : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(
          color: relay.isRelayRunning ? .clear : GeminiVoiceTheme.accentColor.opacity(0.3),
          radius: 10,
          x: 0,
          y: 4
        )
      }
      .buttonStyle(.plain)
      .disabled(relay.isRelayStarting)
      .accessibilityIdentifier("relay-control-button")
      .sensoryFeedback(.impact(weight: .medium), trigger: relay.isRelayRunning)
    }
    .glassCard(cornerRadius: 22, padding: 20)
  }

  private var relayHeading: String {
    if relay.isRelayRunning {
      return "Background relay is active"
    } else if relay.isRelayStarting {
      return "Starting relay automatically…"
    } else {
      return "Relay is off — tap below to start"
    }
  }

  private func toggleRelayState() {
    if relay.isRelayRunning {
      relay.stopRelay()
    } else {
      Task { await relay.startRelay() }
    }
  }
}
