import SwiftUI

struct ModelsInfoSection: View {
  @Bindable var configuration: AppConfiguration

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(configuration.embeddedKeyDescription)
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(
        "Dictate and Translate stream audio while you speak. Finish inserts the final result; Cancel stops and discards it. A temporary recording provides fallback if Live fails."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      LabeledContent("Active transcription model") {
        Text(configuration.activeTranscriptionModelDisplay)
          .font(.caption.monospaced())
          .foregroundStyle(GeminiVoiceTheme.accentColor)
          .textSelection(.enabled)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityIdentifier("active-transcription-model")
      .accessibilityLabel("Active transcription model")
      .accessibilityValue(configuration.activeTranscriptionModelDisplay)

      HStack(spacing: 12) {
        Text("Gemini Live model")
          .font(.subheadline)
        Spacer(minLength: 8)
        Picker("Gemini Live model", selection: $configuration.liveTranscriptionModel) {
          ForEach(GeminiLiveModel.allAvailable) { model in
            Text(model.displayName).tag(model.id)
          }
        }
        .pickerStyle(.menu)
        .tint(GeminiVoiceTheme.accentColor)
        .accessibilityIdentifier("gemini-live-model-picker")
      }

      LabeledContent("Fallback transcription model") {
        Text(configuration.transcriptionModel)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    }
  }
}

typealias ModelsInfoSettingsSection = ModelsInfoSection
