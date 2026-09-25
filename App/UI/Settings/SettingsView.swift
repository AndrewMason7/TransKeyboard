import SwiftUI

struct SettingsView: View {
  @Bindable var configuration: AppConfiguration
  @Bindable var relay: RelayController

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        // Card 1: Keyboard Access & Setup
        KeyboardSetupCard()

        // Card 2: Speech & AI Intelligence (Model Picker, Telemetry, and Inline Local Gemma)
        SpeechEngineSection(
          configuration: configuration,
          downloadManager: relay.modelDownloadManager
        )
        .glassCard(cornerRadius: 20, padding: 18)

        // Card 3: Preferences & Security (Translation, Relay Lifecycle, API Credentials)
        VStack(alignment: .leading, spacing: 18) {
          TranslationSection(configuration: configuration)

          Divider()
            .overlay(Color.primary.opacity(0.08))

          RelayLifecycleSection(configuration: configuration)

          Divider()
            .overlay(Color.primary.opacity(0.08))

          CredentialsSection(configuration: configuration)
        }
        .glassCard(cornerRadius: 20, padding: 18)

        // Privacy note
        privacyFooter
      }
      .padding(.horizontal, 16)
      .padding(.top, 6)
      .padding(.bottom, 36)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .navigationTitle("Settings")
  }

  private var privacyFooter: some View {
    Label(
      "While the relay is on, iOS shows microphone access because the audio session stays armed. After Dictate or Translate, microphone audio streams to Google Gemini Live; Finish inserts the result, while Cancel stops streaming and discards it. A local fallback recording is deleted after success, or kept on this iPhone for Retry after a failure.",
      systemImage: "lock.shield"
    )
    .font(.caption)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, 6)
  }
}
