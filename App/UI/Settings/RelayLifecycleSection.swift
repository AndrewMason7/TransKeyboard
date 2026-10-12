import SwiftUI

struct RelayLifecycleSection: View {
  @Bindable var configuration: AppConfiguration

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Background Relay", systemImage: "antenna.radiowaves.left.and.right")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      Toggle("Auto-start on launch", isOn: $configuration.autoStartRelayOnLaunch)
        .font(.subheadline)
        .tint(GeminiVoiceTheme.accentColor)
        .accessibilityIdentifier("relay-auto-start-toggle")
        .sensoryFeedback(.selection, trigger: configuration.autoStartRelayOnLaunch)

      Toggle("Auto-stop on exit", isOn: $configuration.autoStopRelayOnBackground)
        .font(.subheadline)
        .tint(GeminiVoiceTheme.accentColor)
        .accessibilityIdentifier("relay-auto-stop-toggle")
        .sensoryFeedback(.selection, trigger: configuration.autoStopRelayOnBackground)

      if configuration.autoStopRelayOnBackground {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.top, 1)

          Text("Relay stops when leaving the app. Keyboard dictation in other apps (Messages, Safari) will be disabled.")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier("relay-auto-stop-warning")
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      Divider()
        .padding(.vertical, 2)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Auto-pause idle timeout")
              .font(.subheadline)
            Text(
              configuration.relayIdleTimeout.isNever
                ? "Relay stays armed until manually stopped"
                : "Pauses after inactivity to save battery"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
          }
          Spacer()
          Picker(
            "Auto-pause timeout",
            selection: Binding(
              get: {
                if configuration.relayIdleTimeout.isNever {
                  return -1
                } else if RelayIdleTimeout.presetSeconds.contains(configuration.relayIdleTimeoutSeconds) {
                  return configuration.relayIdleTimeoutSeconds / 60
                } else {
                  return -2
                }
              },
              set: { newMinutes in
                if newMinutes == -1 {
                  configuration.relayIdleTimeoutSeconds = -1
                } else if newMinutes == -2 {
                  if configuration.relayIdleTimeoutSeconds <= 0 || RelayIdleTimeout.presetSeconds.contains(configuration.relayIdleTimeoutSeconds) {
                    configuration.relayIdleTimeoutSeconds = 7 * 60
                  }
                } else {
                  configuration.relayIdleTimeoutSeconds = newMinutes * 60
                }
              }
            )
          ) {
            Text("2 minutes (Default)").tag(2)
            Text("5 minutes").tag(5)
            Text("10 minutes").tag(10)
            Text("15 minutes").tag(15)
            Text("30 minutes").tag(30)
            Text("1 hour").tag(60)
            Text(
              isCustomTimeout
                ? "Custom (\(configuration.relayIdleTimeoutSeconds / 60) min)"
                : "Custom…"
            ).tag(-2)
            Text("Never (Stay armed)").tag(-1)
          }
          .pickerStyle(.menu)
          .tint(GeminiVoiceTheme.accentColor)
          .accessibilityIdentifier("relay-idle-timeout-picker")
        }

        if isCustomTimeout {
          HStack {
            Text("Custom duration:")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Stepper(
              "\(max(1, configuration.relayIdleTimeoutSeconds / 60)) min",
              value: Binding(
                get: { max(1, configuration.relayIdleTimeoutSeconds / 60) },
                set: { configuration.relayIdleTimeoutSeconds = max(1, $0) * 60 }
              ),
              in: 1...240
            )
            .accessibilityIdentifier("relay-custom-timeout-stepper")
          }
          .padding(.top, 2)
        }
      }
    }
    .animation(.easeInOut(duration: 0.2), value: configuration.autoStopRelayOnBackground)
    .animation(.easeInOut(duration: 0.2), value: configuration.relayIdleTimeoutSeconds)
  }

  private var isCustomTimeout: Bool {
    configuration.relayIdleTimeoutSeconds > 0
      && !RelayIdleTimeout.presetSeconds.contains(configuration.relayIdleTimeoutSeconds)
  }
}
