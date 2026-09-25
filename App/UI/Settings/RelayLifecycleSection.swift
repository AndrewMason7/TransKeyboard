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
    }
    .animation(.easeInOut(duration: 0.2), value: configuration.autoStopRelayOnBackground)
  }
}
